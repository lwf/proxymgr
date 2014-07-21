module ProxyMgr
  module Platform
    require 'proxymgr/platform/linux'

    def self.method_missing(sym, *args)
      case RUBY_PLATFORM
      when /linux/
        Platform::Linux.send(sym, *args)
      else
        fail UnsupportedPlatform "Your platform is not supported"
      end
    end

    class UnsupportedPlatform < Exception; end
  end
end
