module ProxyMgr
  class ZKClient 
    require 'zookeeper'
    require 'state_machine'
    require 'forwardable'

    extend Forwardable

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

    def_delegators :@zookeeper, :get_children, :get, :create, :delete

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
  end
end
