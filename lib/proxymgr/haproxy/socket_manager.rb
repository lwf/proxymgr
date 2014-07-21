module ProxyMgr
  class Haproxy
    class SocketManager
      require 'socket'
      require 'fcntl'

      include Logging

      attr_reader :sockets

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
          socket = for_port(backend.port)
          mapping[backend.port] = socket.fileno if socket
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
          @sockets[port].setsockopt(::Socket::SOL_SOCKET, ::Socket::SO_REUSEADDR, 1)
          retries = 0
          until retries > 5
            begin
              @sockets[port].bind(::Socket.pack_sockaddr_in(port, '0.0.0.0'))
              break
            rescue Errno::EADDRINUSE
              logger.info "Could not bind to #{port}: retrying..."
              sleep 1
              retries += 1
            end
          end
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
