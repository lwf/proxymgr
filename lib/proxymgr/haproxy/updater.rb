module ProxyMgr
  class Haproxy
    class Updater
      include Logging

      def initialize(socket)
        @socket       = socket
        @old_watchers = {}
      end

      def produce_changeset(watchers)
        if @socket and @socket.connected?
          new_state = Hash[watchers.map do |name, watcher|
            [name, watcher.servers]
          end]
          proxy_state = haproxy_state
          restart_needed = false
          (proxy_state.keys + new_state.keys).uniq.each do |name|
            if @old_watchers[name] and watchers[name]
              restart_needed = @old_watchers[name] != watchers[name]
            else
              restart_needed = true
            end
          end
          changeset = Set.new(restart_needed, {}, {})
          diff(new_state, proxy_state, changeset) unless restart_needed
          @old_watchers = watchers
          changeset
        else
          logger.debug 'No socket, not doing diffing'
          Set.new(true, {}, {})
        end
      end

      private

      def haproxy_state
        @socket.servers.each_with_object({}) do |server, servers|
          backend = servers[server.backend] ||= { :disabled => [], :enabled => [] }
          if server.disabled?
            backend[:disabled] << server.name
          else
            backend[:enabled] << server.name
          end
        end
      end

      def diff(new_state, proxy_state, changeset)
        new_state.each_with_object(changeset) do |(backend, servers), cs|
          if proxy_state[backend]
            enabled    = proxy_state[backend][:enabled]
            to_disable = enabled - servers

            disabled  = proxy_state[backend][:disabled]
            to_enable = (disabled & servers)
            if ((enabled - to_disable) + to_enable).sort != servers.sort
              cs.restart_needed = true
            end

            cs.disable[backend] = to_disable
            cs.enable[backend]  = to_enable
          end
        end
      end

      class Set < Struct.new(:restart_needed, :disable, :enable)
        def restart_needed?
          restart_needed
        end
      end
    end
  end
end
