require 'spec_helper'

describe ProxyMgr::Watcher::Base do
  before(:each) do
    @sm = double(ProxyMgr::ServiceManager)
  end

  it 'starts if port is correctly specified' do
    started = false
    watcher = ProxyMgr::Watcher::Dummy.new('test', {'port' => 8080}, @sm) { started = true }
    started.should == true
  end

  it 'does not start if port is not an integer' do
    started = false
    watcher = ProxyMgr::Watcher::Dummy.new('test', {'port' => 'false'}, @sm) { started = true }
    started.should == false
  end

  it 'does not start if port is invalid' do
    started = false
    watcher = ProxyMgr::Watcher::Dummy.new('test', {'port' => 0}, @sm) { started = true }
    started.should == false
  end

  it 'does start if listen_options specified and is an array' do
    started = false
    watcher = ProxyMgr::Watcher::Dummy.new('test', {'port' => 65535, 'listen_options' => ['a config option', 'another']}, @sm) { started = true }
    started.should == true
  end
end
