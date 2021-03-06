module ProxyMgr
  module Watcher
    class Zookeeper < Base
      require 'yajl/json_gem'
      require 'zoology'

      def watch
        @zookeeper  = Zoology::Client.new(@config['server'])
        @path_cache = Zoology::PathCache.new(@zookeeper,
                                             @config['path'],
                                             &method(:watch_zookeeper))
        @zk_mapping = {}
        @zookeeper.connect
      end

      def shutdown
        @zookeeper.close if @zookeeper
      end

      def validate_config
        unless @config['path'].is_a? String and
          @config['path'] =~ /^\// and
          @config['path'] !~ /\/$/

          logger.warn "'path' is not a valid Zookeeper path"
          return
        end

        unless @config['server'].is_a? String and
            @config['server'] =~ /^(?:.*:\d{1,6}){1,}$/
          logger.warn "'server' is not properly specified"
          return
        end

        true
      end

      private

      def watch_zookeeper(path, type, req)
        if type == :update
          begin
            config = JSON.parse(req[:data])
            server = "#{config['address']}:#{config['port']}"
            @zk_mapping[path] = server
          rescue Exception => e
            logger.warn "Could not parse config information for backend #{path}: #{e.message}"
          end
        else
          @zk_mapping.delete(path)
        end
        update_servers(@zk_mapping.values.sort)
      end

      def update_servers(servers)
        @servers = servers
        @manager.update_backends
      end
    end
  end
end
