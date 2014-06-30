module ProxyMgr
  module Watcher
    class Campanjazk < Zookeeper
      def watch
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

      def update_servers(children)
        servers = children.map { |child| "#{child}:#{@config['port']}" }.sort
        if @servers != servers
          @servers = servers
          @manager.update_backends
        end
      end
    end
  end
end
