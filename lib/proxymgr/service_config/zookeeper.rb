module ProxyMgr
  module ServiceConfig
    class Zookeeper < Base
      require 'yajl/json_gem'
      require 'zoology'

      include Logging

      def start
        logger.debug "starting service_config"
        @services = {}

        @client     = Zoology::Client.new(@config['servers'])
        @path_cache = Zoology::PathCache.new(@client,
                                             @config['path'],
                                             &method(:watch))
        @client.connect
      end

      private

      def watch(path, type, req)
        name = File.basename(path)
        if type == :update
          config = JSON.parse(req[:data])
          @manager.update_service(name, config)
        else
          logger.debug "deleting service #{name}"
          @manager.delete_service(name)
        end
      end
    end
  end
end
