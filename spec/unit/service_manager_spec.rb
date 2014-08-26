require 'spec_helper'

describe ProxyMgr::ServiceManager do
  before(:each) do
    @sink    = double(ProxyMgr::Sink)
    @manager = ProxyMgr::ServiceManager.new(@sink)
  end

  it 'adds new services' do
    expect(ProxyMgr::Watcher::Dummy).to receive(:new).with('dummy', {'config' => 'thing'}, @manager)
    @manager.update_service('dummy', {'type' => 'dummy', 'config' => 'thing'})
  end

  it 'starts services if valid' do
    expect_any_instance_of(ProxyMgr::Watcher::Dummy).to receive(:watch)
    ProxyMgr::Watcher::Dummy.any_instance.stub(:valid?) { true }
    @manager.update_service('dummy', {'type' => 'dummy', 'config' => 'thing'})
  end

  it 'shuts down old services when replaced' do
    @manager.update_service('dummy', {'type' => "dummy"})
    expect_any_instance_of(ProxyMgr::Watcher::Dummy).to receive(:shutdown)
    @manager.update_service('dummy', {'type' => "dummy"})
  end

  it 'shuts down serviecs when deleted and notifies sink' do
    @sink.should_receive(:update_backends)
    @manager.update_service('dummy', {'type' => "dummy"})
    expect_any_instance_of(ProxyMgr::Watcher::Dummy).to receive(:shutdown)
    @manager.delete_service('dummy')
  end

  it 'notifies sink when watchers are updated' do
    @manager.update_service('dummy', {'type' => 'dummy'})
    @sink.should_receive(:update_backends)
    @manager.update_backends
  end

  it 'shuts down all services and sink when shut down' do
    @manager.update_service('dummy', {'type' => 'dummy'})
    expect_any_instance_of(ProxyMgr::Watcher::Dummy).to receive(:shutdown)
    @sink.should_receive(:shutdown)
    @manager.shutdown
  end

  it 'does not create services for non-existing watcher types' do
    @manager.update_service('dummy', {'type' => 'NonExisting'}).should == nil
  end
end
