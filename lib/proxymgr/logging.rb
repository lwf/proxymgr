module ProxyMgr
  module Logging
    def logger
      @logger ||= Logging.logger(self.class)
    end

    class << self
      attr_accessor :level

      def logger(name)
        logger = Logger.new(STDOUT)
        logger.level = @level || Logger::INFO
        logger.progname = name
        logger
      end
    end
  end
end
