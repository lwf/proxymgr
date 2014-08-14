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

      def disabled?
        @stats['status'] == 'MAINT'
      end
    end
  end
end
