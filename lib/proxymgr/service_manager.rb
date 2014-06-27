module ProxyMgr
  class ServiceManager
    def initialize(sink)
      @services = {}
      @sink     = sink

      @mutex    = Monitor.new
    end

    def update_service(service, data)
      ProxyMgr.logger.info "Received updated service: #{service}, #{data.inspect}"
    end

    def set_services(services)
      ProxyMgr.logger.info "Received services: #{services.keys.join(', ')}"

      # TODO: shut down existing watchers, start new watchers

      @services = services.inject({}) do |acc, (name, config)|
        klass     = Watcher.const_get(config['type'].capitalize)
        watcher   = klass.new(name, config, self)
        acc[name] = watcher
        acc
      end
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
