module ProxyMgr
  class Haproxy
    require 'proxymgr/haproxy/socket'
    require 'proxymgr/haproxy/updater'
    require 'proxymgr/haproxy/server'
    require 'proxymgr/haproxy/control'
    require 'proxymgr/haproxy/process'
    require 'proxymgr/haproxy/state'
    require 'proxymgr/haproxy/socket_manager'

    include Configurable

    attr_accessor :socket_path

    def initialize
      config_attr :config_file, :path, :global, :defaults

      @socket         = Socket.new
      @control        = Control.new
      @socket_manager = SocketManager.new
      @state          = State.new(@control, @socket_manager)
      @updater        = Updater.new(@socket)
    end

    def version
      `#{path} -v`[/version ([\d\.]+)/, 1].to_f
    end

    def start
      configured do
        configure!
        @state.start
      end
    end

    def shutdown
      @state.stop
      @socket_manager.shutdown
    end

    def update_backends(watchers)
      changeset = @updater.produce_changeset(watchers)
      @state.update_state(watchers, changeset)
    end

    private

    def configure!
      @control.config_file   = config_file
      @control.path          = path

      @socket.path           = socket_path

      @state.config_file     = config_file
      @state.global_config   = global
      @state.defaults_config = defaults
      @state.socket_path     = socket_path
    end
  end
end
