module ProxyMgr
  class FakeProxy
    def initialize(&blk)
      @blk      = blk
      @backends = []
    end

    def update_backends(backends)
      puts "update_bakcends"
      @backends = backends
      @blk.call
    end

    def start; end
  end
end
