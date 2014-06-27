module ProxyMgr
  class ServiceManager
    include Logging

    def initialize(sink)
      @services = {}
      @sink     = sink

      @mutex    = Monitor.new
    end

    def update_service(service, data)
      logger.info "Received updated service: #{service}, #{data.inspect}"
    end

    def add_service(name, config)
      logger.info "Received service: #{name}"

      @services[name].shutdown if @services[name]

      klass           = Watcher.const_get(config['type'].capitalize)
      @services[name] = klass.new(name, config, self)
    end

    def update_backends
      @mutex.synchronize { @sink.write_backends @services }
    end

    def shutdown
      @sink.shutdown
      @services.each { |name, watcher| watcher.shutdown }
    end
  end
end
