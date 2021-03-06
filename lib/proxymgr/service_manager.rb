module ProxyMgr
  class ServiceManager
    include Logging

    def initialize(sink)
      @services = {}
      @sink     = sink

      @service_mutex = Mutex.new
      @sink_mutex    = Mutex.new
    end

    def update_service(name, config)
      logger.info "Received service: #{name}"

      type = config.delete('type')
      begin
        klass           = watcher_class(type)
        @service_mutex.synchronize do
          @services[name].shutdown if @services[name]
          w = @services[name] = klass.new(name, config, self)
          w.watch if w.valid?
        end
      rescue NameError
        logger.warn "Could not find implementation for #{type}. Not adding service #{name}"
        nil
      end
    end

    def delete_service(name)
      @service_mutex.synchronize do
        svc = @services.delete(name)
        svc.shutdown if svc
      end
      update_backends
    end

    def update_backends
      @sink_mutex.synchronize { @sink.update_backends @services }
    end

    def shutdown
      @sink.shutdown
      @services.each { |_name, watcher| watcher.shutdown }
    end

    private

    def watcher_class(type)
      Watcher.const_get(type.capitalize)
    end
  end
end
