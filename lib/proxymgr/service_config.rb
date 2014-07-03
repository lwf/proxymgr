module ProxyMgr
  module ServiceConfig
    require 'proxymgr/service_config/base'
    require 'proxymgr/service_config/zookeeper'

    def self.create(manager, config)
      type = config.delete('type')
      impl = ServiceConfig.const_get(type.capitalize)
      impl.new(manager, config)
    end
  end
end
