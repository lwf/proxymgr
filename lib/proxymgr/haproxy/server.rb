module ProxyMgr
  class Haproxy
    class Server
      attr_reader :stats

      def initialize(haproxy, stats)
        @haproxy = haproxy
        @stats   = stats
      end

      def backend
        @stats['pxname']
      end

      def name
        @stats['svname']
      end

      def disable
        @haproxy.disable backend, name
      end

      def shutdown
        @haproxy.shutdown backend, name
      end

      def disabled?
        @stats['status'] == 'MAINT'
      end
    end
  end
end
