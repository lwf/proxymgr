module ProxyMgr
  module Watcher
    class Zookeeper
      require 'state_machine'

      include Logging

      attr_reader :servers

      def initialize(name, config, manager)
        @name     = name
        @manager  = manager
        @config   = config

        @servers  = []

        super()

        @zookeeper = ZKClient.new
        @zookeeper.on_connected = lambda { watch }

        @zookeeper.connect
      end

      def shutdown; end

      def watch
        logger.debug "Now watching"
      end
    end
  end
end
