module ProxyMgr
  module Watcher
    class Zookeeper < Base
      def watch
        @zookeeper = ZKClient.new
        @zookeeper.on_connected { watch_zookeeper }
        @zookeeper.connect
      end

      def shutdown
        @zookeeper.close
      end

      private

      def watch_zookeeper
        # TODO: synchronized. watch could be called from the zookeeper thread while we're running
        cb = ::Zookeeper::Callbacks::WatcherCallback.new { |event| watch }
        req = @zookeeper.get_children(:path => @config['path'], :watcher => cb)
        case req[:rc] 
        when ::Zookeeper::ZOK
          update_servers(req[:children])
        when ::Zookeeper::ZNONODE
          @zookeeper.when_path(@config['path']) { watch }
        else
          logger.warn "get_children returned #{req[:rc].to_s}"
        end
      end
    end
  end
end
