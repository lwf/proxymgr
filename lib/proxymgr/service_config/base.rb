module ProxyMgr
  module ServiceConfig
    class Base
      def initialize(manager, config)
        @manager = manager
        @config  = config
      end

      def start
        fail Exception 'Should be overridden'
      end
    end
  end
end
