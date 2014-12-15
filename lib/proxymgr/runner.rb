module ProxyMgr
  class Runner
    def initialize(config_file, loglevel)
      @config_file     = config_file
      @haproxy         = ProxyMgr::Haproxy.new
      @sink            = ProxyMgr::Sink.new(@haproxy)
      @service_manager = ProxyMgr::ServiceManager.new(@sink)

      ProxyMgr::Logging.level = loglevel
      Zoology::Logging.level  = loglevel
    end


    def run
      configure!

      if @haproxy.version < 1.5
        $stderr.puts 'ProxyMgr requires haproxy version 1.5 or later.'
        exit 1
      end

      @sink.start
      @service_config.start

      begin
        Signal.trap(:HUP) do
          Thread.new do
            configure!
            @haproxy.reload
            @sink.force_update
          end.join
        end

        [:INT, :TERM].each do |sig|
          Signal.trap(sig) do
            begin
              Thread.new { @service_manager.shutdown }.join
            rescue Exception => e
              p e
              p e.backtrace
            end
            exit 0
          end
        end

        sleep
      rescue SystemExit
      rescue NameError, Exception => e
        @service_manager.shutdown
        raise e
      end
    end

    private

    def configure!
      begin
        config                 = ProxyMgr::Config.new(@config_file)
        haproxy_config         = config['haproxy']
        @haproxy.path          = haproxy_config['path']
        @haproxy.config_file   = haproxy_config['config_path']
        @haproxy.socket_path   = haproxy_config['socket_path']
        @haproxy.global        = haproxy_config['global']
        @haproxy.defaults      = haproxy_config['defaults']
        @service_config        = ServiceConfig.create(@service_manager,
                                                      config['service_config'])

      rescue ProxyMgr::Config::ConfigException => e
        $stderr.puts "Failed to load config: #{e}"
      end
    end
  end
end
