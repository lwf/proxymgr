module ProxyMgr
  module ServiceConfig
    class Base
      def initialize(manager, config)
        @manager = manager
        @config  = config

        start
      end

      def start
        raise Exception.new "Should be overridden"
      end
    end
  end
end
