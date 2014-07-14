module ProxyMgr
  class Haproxy
    require 'thread'
    require 'zlib'
    require 'tempfile'
    require 'pathname'
    require 'erb'
    require 'proxymgr/process_manager'
    require 'proxymgr/haproxy/socket'
    require 'proxymgr/haproxy/updater'
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
      @updater = Updater.new(@socket)

      @state.start
    end

    def shutdown
      @state.stop
    end

    def update_backends(watchers)
      changeset = @updater.produce_changeset(watchers)
      @state.update_state(watchers, changeset)
    end
  end
end
