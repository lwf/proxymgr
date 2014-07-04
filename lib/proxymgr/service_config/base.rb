module ProxyMgr
  module ServiceConfig
    class Base
      def initialize(manager, config)
        @manager = manager
        @config  = config

        start
      end

      def start
        fail Exception 'Should be overridden'
      end
    end
  end
end
