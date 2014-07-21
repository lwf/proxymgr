module ProxyMgr
  module Watcher
    class Base
      attr_reader :servers, :port, :listen_options, :server_options

      include Logging

      def initialize(name, config, manager)
        @name           = name
        @manager        = manager
        @config         = config

        @servers        = []
        @listen_options = @config['listen_options']
        @server_options = @config['server_options']
        @port           = @config['port']

        unless @port
          warn 'port is not defined'
          return
        end

        unless @port.is_a? Integer and (@port > 0 and @port <= 65535)
          warn 'port is not an integer or not valid'
          return
        end

        unless !@listen_options || @listen_options.is_a?(Array)
          warn 'listen_options is not an array'
          return
        end

        unless !@server_options || @server_options.is_a?(Array)
          warn 'server_options is not an array'
          return
        end

        watch
      end

      def watch
        fail Exception 'This method should be overridden'
      end

      def shutdown; end

      private

      def warn(msg)
        logger.warn "#{@name}: #{msg}. This watcher will not start."
      end
    end
  end
end
