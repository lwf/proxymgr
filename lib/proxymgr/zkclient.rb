module ProxyMgr
  class ZKClient 
    require 'zookeeper'
    require 'state_machine'

    include Logging

    state_machine :state, :initial => :disconnected do
      after_transition [:expired, :disconnected] => :connecting do |fsm|
        fsm.reopen
      end

      after_transition :connecting => :expired do |fsm|
        fsm.call(:on_expired)
        fsm.connect
      end

      after_transition :connected => :disconnected do |fsm|
        fsm.call(:on_disconnected)
        fsm.connect
      end

      after_transition :connecting => :connected do |fsm|
        fsm.call(:on_connected)
      end

      event :connect do
        transition [:disconnected, :expired] => :connecting
      end

      event :connected do
        transition :connecting => :connected
      end

      event :connecting do
        transition :connected => :disconnected
      end

      event :expired do
        transition :connecting => :expired
      end
    end

    attr_accessor :on_expired, :on_connected, :on_disconnected

    def initialize(servers = 'localhost:2181', opts = {})
      super()

      @servers   = servers
      @heartbeat = opts[:heartbeat] || 2000
    end

    def reopen
      if @zookeeper
        @zookeeper.reopen
      else
        watcher = lambda do |event|
          case event[:state]
          when ::Zookeeper::ZOO_CONNECTED_STATE
            logger.debug "Received connected state"
            connected
          when ::Zookeeper::ZOO_CONNECTING_STATE
            logger.debug "Received connecting state"
            connecting
          when ::Zookeeper::ZOO_EXPIRED_SESSION_STATE
            logger.debug "Received expired state"
            expired
          end
        end
        @zookeeper = ::Zookeeper.new(@servers, @heartbeat, watcher)
      end
    end

    def call(event_type)
      if blk = send(event_type)
        blk.call
      end
    end

    def when_path(path, &blk)
      wait_for_path(path, path, [], &blk)
    end

    def method_missing(sym, *args, &blk)
      @zookeeper.send(sym, *args, &blk)
    end

    private

    def wait_for_path(complete_path, wait_path, rest = [], &blk)
      cb = ::Zookeeper::Callbacks::WatcherCallback.new do |event|
        next_path = join(wait_path, rest.first)
        if @zookeeper.get(:path => next_path)[:rc] == ::Zookeeper::ZOK
          if next_path == complete_path
            logger.debug "#{current_path} now exists, watching it"
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
