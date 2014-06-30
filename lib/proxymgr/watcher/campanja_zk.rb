module ProxyMgr
  module Watcher
    class Campanjazk < Zookeeper
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
