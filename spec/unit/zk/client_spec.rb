require 'spec_helper'

describe ProxyMgr::ZK::Client do
  before(:each) do
    @client  = ProxyMgr::ZK::Client.new('localhost', {}, FakeZookeeper)
    @fake_zk = @client.connect
    @client.stub(:watcher_callback) { |&blk| @fake_zk.watcher_callback(&blk) }
  end

  it 'tries to reconnect when sessions have expired' do
    expect(@fake_zk).to receive(:reopen)
    @fake_zk.expired!
  end

  describe '#when_path' do
    it 'calls block immediately when path exists' do
      @fake_zk.create(:path => '/a', :data => 'test')
      called = false
      @client.when_path('/a') { called = true }
      called.should == true
    end

    it 'recursively places watches when path is not available' do
      called = false
      expect(@fake_zk).to receive(:get_children).with(hash_including(:path => '/a/b/c')).and_call_original
      expect(@fake_zk).to receive(:get_children).with(hash_including(:path => '/')).and_call_original
      @client.when_path('/a/b/c') { called = true }
      expect(@fake_zk).to receive(:get_children).with(hash_including(:path => '/a')).and_call_original
      @fake_zk.create(:path => '/a')
      expect(@fake_zk).to receive(:get_children).with(hash_including(:path => '/a/b')).and_call_original
      @fake_zk.create(:path => '/a/b')
      expect(@fake_zk).to receive(:get).with(hash_including(:path => '/a/b/c')).and_call_original
      @fake_zk.create(:path => '/a/b/c')
      called.should == true
    end
  end
end
