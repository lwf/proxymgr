module ProxyMgr
  class Haproxy
    require 'proxymgr/haproxy/socket'
    require 'proxymgr/haproxy/updater'
    require 'proxymgr/haproxy/server'
    require 'proxymgr/haproxy/control'
    require 'proxymgr/haproxy/process'
    require 'proxymgr/haproxy/state'
    require 'proxymgr/haproxy/socket_manager'

    def initialize(path, config_file, opts = {})
      @path             = path
      @config_file      = config_file

      @socket_path      = opts[:socket]
      @global_config    = opts[:global]
      @defaults_config  = opts[:defaults]

      @socket           = @socket_path ? Socket.new(@socket_path) : nil

      @control          = nil
    end

    def version
      `#{@path} -v`[/version ([\d\.]+)/, 1].to_f
    end

    def start
      @socket         = @socket_path ? Socket.new(@socket_path) : nil
      @control        = Control.new(@path, @config_file)
      opts            = {:defaults    => @defaults_config,
                         :global      => @global_config,
                         :socket_path => @socket_path}
      @socket_manager = SocketManager.new
      @state          = State.new(@control, @config_file, @socket_manager, @socket, opts)
      @updater        = Updater.new(@socket)

      @state.start
    end

    def shutdown
      @state.stop
      @socket_manager.shutdown
    end

    def update_backends(watchers)
      changeset = @updater.produce_changeset(watchers)
      @state.update_state(watchers, changeset)
    end
  end
end
