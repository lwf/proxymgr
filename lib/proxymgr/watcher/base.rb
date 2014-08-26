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
      end

      def watch
        fail Exception 'This method should be overridden'
      end

      def shutdown; end

      def ==(obj)
        if obj.is_a? Watcher::Base
          obj.listen_options == @listen_options and
            obj.server_options == @server_options and
            obj.port == @port
        else
          super
        end
      end

      def valid?
        unless @port
          warn 'port is not defined'
          return false
        end

        unless @port.is_a? Integer and (@port > 0 and @port <= 65535)
          warn 'port is not an integer or not valid'
          return false
        end

        unless !@listen_options || @listen_options.is_a?(Array)
          warn 'listen_options is not an array'
          return false
        end

        unless !@server_options || @server_options.is_a?(Array)
          warn 'server_options is not an array'
          return false
        end

        if has_validation? and !validate_config
          warn 'config failed to validate'
          return false
        end

        true
      end

      private

      def has_validation?
        respond_to? :validate_config
      end

      def warn(msg)
        logger.warn "#{@name}: #{msg}. This watcher will not start."
      end
    end
  end
end
