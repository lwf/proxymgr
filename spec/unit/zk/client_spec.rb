require 'spec_helper'

describe ProxyMgr::ZK::Client do
  before do
    @client  = ProxyMgr::ZK::Client.new('localhost', {}, FakeZookeeper)
    @client.connect
    @fake_zk = @client.instance_variable_get(:@zookeeper)
    @client.stub(:watcher_callback) { |&blk| @fake_zk.watcher_callback(&blk) }
  end

  it 'tries to reconnect when sessions have expired' do
    expect(@fake_zk).to receive(:reopen)
    @fake_zk.expired!
  end

  describe '#when_path' do
    #it 'calls block immediately when path exists' do
    #  @fake_zk.create(:path => '/a', :data => 'test')
    #  called = false
    #  @client.when_path('/a') { called = true }
    #  called.should == true
    #end

    it 'recursively places watches when path is not available' do
      @fake_zk.create(:path => '/a')
      expect(@fake_zk).to receive(:get_children)
      called = false
      @client.when_path('/a/b/c') { called = true }
    end
  end
end
