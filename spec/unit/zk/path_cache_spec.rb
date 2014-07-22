require 'spec_helper'

describe ProxyMgr::ZK::PathCache do
  before(:each) do
    @client  = ProxyMgr::ZK::Client.new('localhost', {}, FakeZookeeper)
    @fake_zk = @client.connect
    @client.stub(:watcher_callback) { |&blk| @fake_zk.watcher_callback(&blk) }
  end

  context 'not connected' do
    it 'establishes watches when connected' do
      @fake_zk.disconnected!
      called = false
      path_cache = ProxyMgr::ZK::PathCache.new(@client, '/a') do |path, type, data|
        called = true
      end
      @fake_zk.connected!
      @fake_zk.create(:path => '/a')
      @fake_zk.create(:path => '/a/b')
      called.should == true
    end
  end

  context 'path does not exist' do
    it 'waits for a sub path of path to exist' do
      called = false
      path_cache = ProxyMgr::ZK::PathCache.new(@client, '/a') do |path, type, data|
        called = true
      end
      @fake_zk.create(:path => '/a')
      @fake_zk.create(:path => '/a/b')
      called.should == true
    end
  end

  it 're-establishes watches when sessions expire' do
    called = false
    path_cache = ProxyMgr::ZK::PathCache.new(@client, '/a') do |path, type, data|
      called = true
    end
    @fake_zk.expired!
    @fake_zk.create(:path => '/a')
    @fake_zk.create(:path => '/a/b')
    called.should == true
  end

  it 'calls the callback for each sub-path created with the appropriate data' do
    paths = []
    data  = []
    path_cache = ProxyMgr::ZK::PathCache.new(@client, '/a') do |path, type, event|
      paths << path
      data << event.data
    end
    @fake_zk.create(:path => '/a')
    @fake_zk.create(:path => '/a/b', :data => 'path1')
    @fake_zk.create(:path => '/a/c', :data => 'path2')
    data.should == ['path1', 'path2']
    paths.should == ['/a/b', '/a/c']
  end
end
