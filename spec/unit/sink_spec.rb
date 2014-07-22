require 'spec_helper'

describe ProxyMgr::Sink do
  require 'absolute_time'

  before(:each) do
    @manager = double(ProxyMgr::ServiceManager)
    @watcher = ProxyMgr::Watcher::Dummy.new('test', {'port' => 1}, @manager)
    @watcher.servers = ['a', 'b']
    @mutex   = Mutex.new
    @cv      = ConditionVariable.new
  end

  it 'calls update_backends after a delay' do
    t1       = AbsoluteTime.now
    elapsed  = nil
    proxy    = ProxyMgr::FakeProxy.new do
      elapsed = AbsoluteTime.now-t1
      @mutex.synchronize { @cv.signal }
    end
    sink     = ProxyMgr::Sink.new(proxy, :default_timeout => 2)
    sink.update_backends('test' => @watcher)
    @mutex.synchronize { @cv.wait(@mutex) }
    elapsed.should >= 2
  end
end
