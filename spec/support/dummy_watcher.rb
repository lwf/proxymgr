module ProxyMgr
  module Watcher
    class Dummy < Base
      attr_reader :name, :config, :manager

      def initialize(name, config, manager, &blk)
        @name    = name
        @config  = config
        @manager = manager
        @blk     = blk

        super
      end

      def watch
        @blk.call
      end
    end
  end
end
