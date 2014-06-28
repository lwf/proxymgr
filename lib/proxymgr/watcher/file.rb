module ProxyMgr
  module Watcher
    class File
      attr_reader :servers

      include Logging

      def initialize(name, config, manager)
        @name     = name
        @manager  = manager
        @config   = config

        @servers  = []

        @thread   = nil

        watch
      end

      def shutdown
      end

      private

      def watch
        @thread = Thread.new do
          loop do
            if ::File.file? @config['file']
              servers = ::File.readlines(@config['file']).map(&:chomp).sort
              if @servers != servers
                @servers = servers
                @manager.update_backends
              end
            else
              logger.info "#{@name} is not a file, ignoring..."
            end

            sleep 5
          end
        end
        @thread.abort_on_exception = true
      end
    end
  end
end
