module ProxyMgr
  module Watcher
    class Dummy
      attr_reader :name, :config, :manager

      def initialize(name, config, manager)
        @name    = name
        @config  = config
        @manager = manager
      end
    end
  end
end
