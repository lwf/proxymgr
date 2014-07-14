require 'spec_helper'

describe ProxyMgr::Haproxy::Updater, '#produce_changeset' do
  before do
    @socket  = double(ProxyMgr::Haproxy::Socket)
    @updater = ProxyMgr::Haproxy::Updater.new(@socket)
  end

  it 'should require restarts if no stats socket is available' do
    @socket.should_receive(:connected?) { false }
    changeset = @updater.produce_changeset(nil)
    changeset.restart_needed?.should == true
  end

  it 'should require restarts if a new server is provided' do
    @socket.should_receive(:connected?) { true }
    @socket.should_receive(:servers) do
      ['a', 'b'].map { |name| new_mock_server('dummy', 'name') }
    end
    watcher = double(ProxyMgr::Watcher::Base)
    watcher.should_receive(:servers) { ['a', 'b', 'c'] }
    changeset = @updater.produce_changeset('dummy' => watcher)
    changeset.restart_needed?.should == true
  end

  it 'should disable servers if they are already added' do
    @socket.should_receive(:connected?) { true }
    @socket.should_receive(:servers) do
      ['a', 'b', 'c'].map { |name| new_mock_server('dummy', name) }
    end
    watcher = double(ProxyMgr::Watcher::Base)
    watcher.should_receive(:servers) { ['a', 'b'] }
    changeset = @updater.produce_changeset('dummy' => watcher)
    changeset.disable.should == {'dummy' => ['c']}
    changeset.restart_needed?.should == false
  end

  it 'should enable servers if they are down and added' do
    @socket.should_receive(:connected?) { true }
    @socket.should_receive(:servers) do
      s = ['a', 'b'].map { |name| new_mock_server('dummy', name) }
      s << new_mock_server('dummy', 'c', 'MAINT')
    end
    watcher = double(ProxyMgr::Watcher::Base)
    watcher.should_receive(:servers) { ['a', 'b', 'c'] }
    changeset = @updater.produce_changeset('dummy' => watcher)
    changeset.enable.should == {'dummy' => ['c']}
    changeset.restart_needed?.should == false
  end

  it 'should require restart if a backend is added' do
    @socket.should_receive(:connected?) { true }
    @socket.should_receive(:servers) { [] }
    watcher = double(ProxyMgr::Watcher::Base)
    watcher.should_receive(:servers) { ['a', 'b'] }
    changeset = @updater.produce_changeset('dummy' => watcher)
    changeset.restart_needed?.should == true
  end

  it 'should require restart if a backend is deleted' do
    @socket.should_receive(:connected?) { true }
    @socket.should_receive(:servers) do
      ['a', 'b', 'c'].map do |name|
        new_mock_server('dummy', name)
      end
    end
    changeset = @updater.produce_changeset({})
    changeset.restart_needed?.should == true
  end
end
