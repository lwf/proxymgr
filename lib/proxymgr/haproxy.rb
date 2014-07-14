module ProxyMgr
  class Haproxy
    require 'thread'
    require 'zlib'
    require 'tempfile'
    require 'pathname'
    require 'erb'
    require 'proxymgr/process_manager'
    require 'proxymgr/haproxy/socket'
    require 'proxymgr/haproxy/server'
    require 'proxymgr/haproxy/process'
    require 'proxymgr/haproxy/state'

    include Logging

    def initialize(path, config_file, opts = {})
      @path             = path
      @config_file      = config_file

      @socket_path      = opts[:socket]
      @global_config    = opts[:global]
      @defaults_config  = opts[:defaults]

      @socket           = @socket_path ? Socket.new(@socket_path) : nil

      @process          = nil
    end

    def version
      `#{@path} -v`[/version ([\d\.]+)/, 1].to_f
    end

    def start
      @socket  = @socket_path ? Socket.new(@socket_path) : nil
      @process = Process.new(@path, @config_file)
      opts     = {:defaults    => @defaults_config,
                  :global      => @global_config,
                  :socket_path => @socket_path}
      @state   = State.new(@process, @config_file, @socket, opts)

      @state.start
    end

    def shutdown
      @state.stop
    end

    def update_backends(watchers)
      changeset = find_existing_backends(watchers)
      @state.update_state(watchers, changeset)
    end

    private

    def find_existing_backends(watchers)
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
        changeset = ChangeSet.new(restart_needed, {}, {})
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
        ChangeSet.new(true, {}, {})
      end
    end

    class ChangeSet < Struct.new(:restart_needed, :disable, :enable)
      def restart_needed?
        restart_needed
      end
    end
  end
end
