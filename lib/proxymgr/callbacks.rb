module ProxyMgr
  module Callbacks
    def call(callback, *args)
      cb = @callbacks[callback]
      cb.call(*args) if cb
    end

    private

    def callbacks(*callbacks)
      @callbacks ||= {}
      callbacks.each do |cb|
        self.class.send(:define_method, cb) { |&blk| @callbacks[cb] = blk }
      end
    end
  end
end
