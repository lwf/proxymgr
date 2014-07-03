module ProxyMgr
  module ServiceConfig
    class Zookeeper < Base
      require 'json'

      include Logging

      def start
        @services = {}

        @client     = ZK::Client.new(@config['servers'])
        @path_cache = ZK::PathCache.new(@client,
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
