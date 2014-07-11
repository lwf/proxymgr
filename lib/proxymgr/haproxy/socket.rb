module ProxyMgr
  class Haproxy
    class Socket
      require 'socket'

      attr_reader :path

      def initialize(path)
        @path = path
      end

      def write(cmd)
        with do |socket|
          socket.puts(cmd + '\n')
          socket.readlines.map(&:chomp)
        end
      end

      private

      def with
        yield UNIXSocket.new(@path)
      end
    end
  end
end
