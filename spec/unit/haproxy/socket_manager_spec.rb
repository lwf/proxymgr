require 'spec_helper'

describe ProxyMgr::Haproxy::SocketManager, '#update' do
  before(:each) do
    @sm = ProxyMgr::Haproxy::SocketManager.new
    Socket.any_instance.stub(:bind) { true }
  end

  it 'creates new sockets when none exist' do
    watcher = double(ProxyMgr::Watcher::Base)
    watcher.stub(:port) { 9090 }
    @sm.update({"test" => watcher})
    @sm.sockets[9090].should be_kind_of(Socket)
  end

  it 'deletes sockets which are no longer part of the state' do
    ports = [9090, 9091]
    watchers = Hash[ports.map do |port|
      watcher = double(ProxyMgr::Watcher::Base)
      watcher.stub(:port) { port }
      ["service_" + port.to_s, watcher]
    end]
    @sm.update(watchers)
    ports.each do |port|
      @sm.sockets[port].should be_kind_of(Socket)
    end
    watchers.delete("service_9090")
    Socket.any_instance.should_receive(:close)
    @sm.update(watchers)
    @sm.sockets[9091].should be_kind_of(Socket)
    @sm.sockets[9090].should == nil
  end

  it 'sets SO_REUSEADDR on sockets' do
    watcher = double(ProxyMgr::Watcher::Base)
    watcher.stub(:port) { 9090 }
    Socket.any_instance.should_receive(:setsockopt).with(::Socket::SOL_SOCKET, ::Socket::SO_REUSEADDR, 1)
    @sm.update("test" => watcher)
  end
end
