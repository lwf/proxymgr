module ProxyMgr
  module Watcher
    class Campanjazk < Zookeeper
      def watch_zookeeper(path, type, req)
        if type == :update
          @zk_mapping[path] = ::File.basename(path)
        else
          @zk_mapping.delete(path)
        end
        update_servers(@zk_mapping.values.sort)
      end

      def update_servers(children)
        servers = children.map { |child| "#{child}:#{@config['port']}" }.sort
        @servers = servers
        @manager.update_backends
      end
    end
  end
end
