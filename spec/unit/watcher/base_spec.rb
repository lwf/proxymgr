require 'spec_helper'

describe ProxyMgr::Watcher::Base do
  before(:each) do
    @sm = double(ProxyMgr::ServiceManager)
  end

  it 'is valid if port is correctly specified' do
    watcher = ProxyMgr::Watcher::Dummy.new('test', {'port' => 8080}, @sm)
    watcher.valid?.should == true
  end

  it 'does not start if port is not an integer' do
    watcher = ProxyMgr::Watcher::Dummy.new('test', {'port' => 'false'}, @sm)
    watcher.valid?.should == false
  end

  it 'does not start if port is invalid' do
    watcher = ProxyMgr::Watcher::Dummy.new('test', {'port' => 0}, @sm)
    watcher.valid?.should == false
  end

  it 'is valid if listen_options specified and is an array' do
    watcher = ProxyMgr::Watcher::Dummy.new('test', {'port' => 65535, 'listen_options' => ['a config option', 'another']}, @sm)
    watcher.valid?.should == true
  end
end
