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
          wait_for_path(@config['path'])
        else
          logger.warn "get_children returned #{req[:rc].to_s}"
        end
      end

      def wait_for_path(path, rest = [])
        cb = ::Zookeeper::Callbacks::WatcherCallback.new do |event|
          next_path = join(path, rest.first)
          if @zookeeper.get(:path => next_path)[:rc] == ::Zookeeper::ZOK
            if next_path == @config['path']
              logger.debug "#{@config['path']} now exists, watching it"
              watch
            else
              logger.debug "#{next_path} exists, moving on to next"
              rest.shift
              wait_for_path(next_path, rest)
            end
          else
            wait_for_path(path, rest)
          end
        end

        req = @zookeeper.get_children(:path => path, :watcher => cb)
        case req[:rc]
        when ::Zookeeper::ZOK
          logger.debug "Now watching #{path}"
        when ::Zookeeper::ZNONODE
          logger.debug "Re-resolving paths"
          path, rest = find_wait_path
          wait_for_path(path, rest)
        else
          logger.warn "wait_for_path #{path} failed: #{req[:rc].to_s}"
        end
      end


      def update_servers(children)
        servers = children.map { |child| "#{child}:#{@config['port']}" }.sort
        if @servers != servers
          @servers = servers
          @manager.update_backends
        end
      end

      def find_wait_path
        parts = split(@config['path'])
        rest = [parts.pop]
        path = '/'
        until parts.empty?
          path = join(*parts)
          if @zookeeper.get(:path => path)[:rc] == ::Zookeeper::ZOK
            break
          end
          rest.unshift parts.pop
        end
        [path, rest]
      end

      def join(*path)
        # TODO: deal with broken path input
        p = ::File.join(*path)
        if p == ""
          "/"
        else
          p
        end
      end
      
      def split(path)
        head, *tail = path.split("/")
        [head] + tail.reject(&:empty?)
      end
    end
  end
end
