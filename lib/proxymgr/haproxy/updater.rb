module ProxyMgr
  class Haproxy
    class Updater
      include Logging

      def initialize(socket)
        @socket = socket
      end

      def produce_changeset(watchers)
        if @socket and @socket.connected?
          new_state = Hash[watchers.map do |name, watcher|
            [name, watcher.servers]
          end]
          old_state = @socket.servers.each_with_object({}) do |server, servers|
            backend = servers[server.backend] ||= { :disabled => [], :enabled => [] }
            if server.disabled?
              backend[:disabled] << server.name
            else
              backend[:enabled] << server.name
            end
          end
          restart_needed = new_state.keys.sort != old_state.keys.sort
          changeset = Set.new(restart_needed, {}, {})
          new_state.each_with_object(changeset) do |(backend, servers), cs|
          if old_state[backend]
            enabled    = old_state[backend][:enabled]
            to_disable = enabled - servers

            disabled  = old_state[backend][:disabled]
            to_enable = (disabled & servers)
            if ((enabled - to_disable) + to_enable).sort != servers.sort
              cs.restart_needed = true
            end

            cs.disable[backend] = to_disable
            cs.enable[backend]  = to_enable
          end
          cs
          end
        else
          logger.debug 'No socket, not doing diffing'
          Set.new(true, {}, {})
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
