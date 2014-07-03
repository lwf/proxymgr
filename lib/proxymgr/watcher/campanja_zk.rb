module ProxyMgr
  module Watcher
    class Campanjazk < Zookeeper
      def update_servers(children)
        servers = children.map { |child| "#{child}:#{@config['port']}" }.sort
        return if @servers == servers
        @servers = servers
        @manager.update_backends
      end
    end
  end
end
