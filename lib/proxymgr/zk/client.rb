module ProxyMgr
  module ZK
    class Client
      require 'zookeeper'

      include Logging
      include Callbacks

      def initialize(servers = 'localhost:2181', opts = {})
        @servers   = servers
        @heartbeat = opts[:heartbeat] || 2000

        callbacks :on_connected, :on_expired, :on_disconnected
      end

      def connect
        logger.debug "Connect to ZK"
        watcher = lambda do |event|
          case event[:state]
          when ::Zookeeper::ZOO_CONNECTED_STATE
            logger.debug "Received connected state"
            call(:on_connected)
          when ::Zookeeper::ZOO_CONNECTING_STATE
            logger.debug "Received connecting state"
            call(:on_disconnected)
          when ::Zookeeper::ZOO_EXPIRED_SESSION_STATE
            logger.debug "Received expired state"
            call(:on_expired)
            reopen
          end
        end
        @zookeeper = ::Zookeeper.new(@servers, @heartbeat, watcher)
      end

      def reopen
        logger.debug "reopen it"
        @zookeeper.reopen
      end

      def connected?
        if @zookeeper
          @zookeeper.connected?
        else
          false
        end
      end

      def when_path(path, &blk)
        req = @zookeeper.get(:path => path)
        if req[:rc] == ::Zookeeper::ZOK
          blk.call
        else
          wait_for_path(path, path, [], &blk)
        end
      end

      def method_missing(sym, *args, &blk)
        logger.debug "Call to zookeeper #{sym.to_s}: #{args.map(&:to_s).join(',')}"
        @zookeeper.send(sym, *args, &blk)
      end

      private

      def wait_for_path(complete_path, wait_path, rest = [], &blk)
        cb = ::Zookeeper::Callbacks::WatcherCallback.create do |event|
          if event.type != ::Zookeeper::ZOO_SESSION_EVENT
            next_path = join(wait_path, rest.first)
            if @zookeeper.get(:path => next_path)[:rc] == ::Zookeeper::ZOK
              if next_path == complete_path
                logger.debug "#{complete_path} now exists, watching it"
                blk.call
              else
                logger.debug "#{next_path} exists, moving on to next"
                rest.shift
                wait_for_path(complete_path, next_path, rest, &blk)
              end
            else
              wait_for_path(complete_path, wait_path, rest, &blk)
            end
          end
        end

        req = @zookeeper.get_children(:path => wait_path, :watcher => cb)
        case req[:rc]
        when ::Zookeeper::ZOK
          logger.debug "Now watching #{wait_path}"
        when ::Zookeeper::ZNONODE
          logger.debug "Re-resolving paths"
          wait_path, rest = find_wait_path(complete_path)
          wait_for_path(complete_path, wait_path, rest, &blk)
        else
          logger.warn "wait_for_path #{wait_path} failed: #{req[:rc].to_s}"
        end
      end

      def find_wait_path(complete_path)
        parts = split(complete_path)
        rest = [parts.pop]
        path = '/'
        until parts.empty?
          path = join(*parts)
          if @zookeeper.get(:path => path)[:rc] == ::Zookeeper::ZOK
            break
          end
          rest.unshift parts.pop
        end
        [path, rest]
      end

      def join(*path)
        p = ::File.join(*path)
        if p == ""
          "/"
        else
          p
        end
      end

      def split(path)
        head, *tail = path.split("/")
        [head] + tail.reject(&:empty?)
      end
    end
  end
end
