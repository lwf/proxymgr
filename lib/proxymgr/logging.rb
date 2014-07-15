module ProxyMgr
  module Logging
    require 'logger'
    require 'stringio'

    def logger
      @logger ||= Logging.logger(self.class)
    end

    class << self
      attr_accessor :level

      def disable!
        @disable = true
      end

      def logger(name)
        sink = @disable ? StringIO.new : STDOUT
        logger = Logger.new(sink)
        logger.level = @level || Logger::INFO
        logger.progname = name
        logger
      end
    end
  end
end
