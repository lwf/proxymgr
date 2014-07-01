module ProxyMgr
  module Watcher
    class Dns < Base
      require 'resolv'

      private

      def watch
        @thread = Thread.new do
          loop do
            hosts = []
            @config['backends'].map do |backend|
              resolver.each_address(backend['name']) do |addr|
                hosts << "#{addr.to_s}:#{backend['port']}"
              end
            end

            hosts.sort!

            if @servers != hosts
              @servers = hosts
              @manager.update_backends
            end

            sleep 5
          end
        end
        @thread.abort_on_exception = true
      end

      def resolver
        Resolv::DNS.new
      end
    end
  end
end
