module ProxyMgr
  module ZK
    class PathCache
      include Logging

      def initialize(client, path, &callback)
        @client   = client
        @watches  = {}
        @watcher  = nil
        @path     = path
        @callback = callback
        @client.on_connected do |_event|
          if @sleep
            logger.debug "Sleeping for #{@sleep}s to avoid thundering herd"
            sleep(@sleep) if @sleep
          end
          watch_paths
        end
        @client.on_expired do |_event|
          @watches.each { |_path, watcher| watcher.shutdown }
          @watches = {}
          @sleep   = rand(10)
        end
        if @client.connected?
          watch_paths
        end
      end

      private

      def watch_paths
        watcher = lambda do |_wpath, type, req|
          if type == :update
            update_watches(req[:children]) if req[:rc] == Zookeeper::ZOK
          else
            @client.when_path(@path) { watch_paths }
          end
        end

        @watcher = Watcher.new(@client, @path, :get_children, &watcher)
        @watcher.watch
      end

      def update_watches(children)
        paths = children.map { |child| File.join(@path, child) }
        (paths - @watches.keys).each do |path|
          @watches[path] = Watcher.new(@client, path, &@callback)
        end
        (@watches.keys - paths).each do |path|
          @watches.delete(path).shutdown
        end
        @watches.each { |_name, watcher| watcher.watch }
      end

      class Watcher
        require 'state_machine'

        include Logging

        state_machine :state, :initial => :not_watching do
          after_transition :not_watching => :watching, :do => :set_watch
          before_transition any => :shutdown, :do => :deleted

          event :watch do
            transition :not_watching => :watching
          end

          event :not_watching do
            transition :watching => :not_watching
          end

          event :shutdown do
            transition all => :shutdown
          end

          state :shutdown do
            def call(type, data = nil)
              puts "delayed call #{type}: #{data.inspect}"
              logger.debug "Received call request, but in shutdown so not doing anything: #{@path}"
            end
          end

          state all - [:shutdown] do
            def call(type, data = nil)
              @callback.call @path, type, data
            end
          end
        end

        def initialize(client, path, zk_call = :get, &callback)
          @client   = client
          @path     = path
          @zk_call  = zk_call
          @callback = callback

          super()
        end

        def set_watch
          watcher = Zookeeper::Callbacks::WatcherCallback.create do |event|
            set_watch if event.type != Zookeeper::ZOO_SESSION_EVENT
          end
          begin
            req = @client.send(@zk_call, :path => @path, :watcher => watcher)
            if req[:rc] == Zookeeper::ZOK
              call(:update, req)
            elsif req[:rc] == Zookeeper::ZNONODE
              shutdown
            else
              not_watching
            end
          rescue Zookeeper::Exceptions::ContinuationTimeoutError
            not_watching
          end
        end

        def deleted
          call(:deleted)
        end
      end
    end
  end
end
