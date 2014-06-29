module ProxyMgr
  module Watcher
    class Zookeeper
      require 'zookeeper'
      require 'state_machine'

      include Logging

      attr_reader :servers

      state_machine :state, :initial => :disconnected do
        after_transition [:expired, :disconnected] => :connecting do |fsm|
          fsm.reopen
        end

        after_transition :connecting => :expired do |fsm|
          fsm.connect
        end

        after_transition :connected => :disconnected do |fsm|
          fsm.connect
        end

        after_transition :connecting => :connected do |fsm|
          fsm.watch
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

      def initialize(name, config, manager)
        @name     = name
        @manager  = manager
        @config   = config

        @servers  = []

        @thread   = nil

        super()

        connect

      end

      def shutdown
        @zookeeper.close if @zookeeper
      end

      def watch
        logger.debug "Now watching"
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
          @zookeeper = ::Zookeeper.new(@config['server'] || 'localhost:2181', 2000, watcher)
        end
      end
    end
  end
end
