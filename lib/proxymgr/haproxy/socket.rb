module ProxyMgr
  class Haproxy
    class Socket
      require 'socket'

      include Configurable

      def initialize
        config_attr :path
      end

      def stats
        headers, *rest = write('show stat')
        headers = headers.gsub(/^# /, '').split(',')
        rest.pop
        rest.map { |d| Hash[headers.zip(d.split(','))] }
      end

      def enable(backend, host)
        write "enable server #{backend}/#{host}"
      end

      def disable(backend, host)
        write "disable server #{backend}/#{host}"
      end

      def shutdown(backend, host)
        write "shutdown sessions server #{backend}/#{host}"
      end

      def servers
        stats.each_with_object([]) do |stat, acc|
          next if %w(FRONTEND BACKEND).include? stat['svname']
          acc << Server.new(self, stat)
        end
      end

      def write(cmd)
        with do |socket|
          socket.puts(cmd + "\n")
          socket.readlines.map(&:chomp)
        end
      end

      def connected?
        return false unless configured?

        begin
          with do |socket|
            socket.write "show info"
          end
        rescue Errno::ECONNREFUSED
        end
      end

      private

      def with
        configured do
          socket = nil
          begin
            socket = UNIXSocket.new(path)
            yield socket
          ensure
            socket.close if socket
          end
        end
      end
    end
  end
end
