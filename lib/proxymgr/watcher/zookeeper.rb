module ProxyMgr
  module Watcher
    class Zookeeper
      require 'state_machine'

      include Logging

      attr_reader :servers

      def initialize(name, config, manager)
        @name     = name
        @manager  = manager
        @config   = config

        @servers  = []

        super()

        @zookeeper = ZKClient.new
        @zookeeper.on_connected = lambda { watch }

        @zookeeper.connect
      end

      def shutdown
        @zookeeper.close
      end

      def watch
        # TODO: synchronized. watch could be called from the zookeeper thread while we're running
        cb = ::Zookeeper::Callbacks::WatcherCallback.new { |event| watch }
        req = @zookeeper.get_children(:path => @config['path'], :watcher => cb)
        case req[:rc] 
        when ::Zookeeper::ZOK
          update_servers(req[:children])
        when ::Zookeeper::ZNONODE
          @zookeeper.when_path(@config['path']) { watch }
        else
          logger.warn "get_children returned #{req[:rc].to_s}"
        end
      end
    end
  end
end
