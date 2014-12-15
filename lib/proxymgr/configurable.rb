module ProxyMgr
  module Configurable
    def config_attr(*sym)
      @config_required ||= []
      @config_required = @config_required + sym

      @config_vars ||= {}

      @config_required.each do |c|
        self.class.send(:define_method, c) { @config_vars[c] }
        self.class.send(:define_method, "#{c.to_s}=".to_sym) { |val| @config_vars[c] = val }
      end
    end

    def configured(&blk)
      if configured?
        blk.call
      else
        raise NotConfiguredException.new
      end
    end

    def configured?
      diff = @config_required - @config_vars.map { |k,v| k if v }.compact
      diff.empty?
    end

    class NotConfiguredException < Exception; end
  end
end
