module ProxyMgr
  module Platform
    module Linux
      def self.max_fd
        File.readlines('/proc/self/status').find { |x| x =~ /^FDSize:/ }.split(':').last.to_i
      end
    end
  end
end
