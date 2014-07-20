module ProxyMgr
  class Haproxy
    class SocketManager
      require 'socket'
      require 'fcntl'

      def initialize
        @sockets = {}
      end

      def shutdown
        @sockets.each do |_port, socket|
          socket.close
        end
      end

      def update(backends)
        fds = backends.each_with_object({}) do |(name, backend), mapping|
          mapping[backend.port] = for_port(backend.port).fileno
        end

        (@sockets.keys - fds.keys).each do |port|
          @sockets.delete(port).close
        end

        fds
      end

      private

      def for_port(port)
        unless @sockets[port]
          @sockets[port] = ::Socket.new(::Socket::AF_INET, ::Socket::SOCK_STREAM, 0)
          @sockets[port].bind(::Socket.pack_sockaddr_in(port, '0.0.0.0'))
          flags = @sockets[port].fcntl(Fcntl::F_GETFD) & ~Fcntl::FD_CLOEXEC
          @sockets[port].fcntl(Fcntl::F_SETFD, flags)
        end
        @sockets[port]
      end

      def stop_port(port)
        @sockets[port].close if @sockets[port]
      end
    end
  end
end
