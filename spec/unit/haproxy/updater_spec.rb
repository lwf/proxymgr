require 'spec_helper'

describe ProxyMgr::Haproxy::Updater, '#produce_changeset' do
  before do
    @socket  = double(ProxyMgr::Haproxy::Socket)
    @sm      = double(ProxyMgr::ServiceManager)
    @updater = ProxyMgr::Haproxy::Updater.new(@socket)
  end

  context 'stats socket not available' do
    before do
      @socket.stub(:connected?) { false }
    end

    it 'should require restarts if no stats socket is available' do
      @socket.stub(:connected?) { false }
      changeset = @updater.produce_changeset(nil)
      changeset.restart_needed?.should == true
    end
  end

  context 'stats socket available' do
    before do
      @socket.stub(:connected?) { true }
    end

    it 'requires restarts if a new server is provided' do
      @socket.should_receive(:servers) do
        ['a', 'b'].map { |name| new_mock_server('dummy', 'name') }
      end
      watcher = ProxyMgr::Watcher::Dummy.new('dummy', {}, @sm)
      watcher.servers = ['a', 'b', 'c']
      changeset = @updater.produce_changeset('dummy' => watcher)
      changeset.restart_needed?.should == true
    end

    it 'disables servers if they are already added' do
      @socket.should_receive(:servers) { [] }
      watcher = ProxyMgr::Watcher::Dummy.new('dummy', {}, @sm)
      watcher.servers = ['a', 'b', 'c']
      @updater.produce_changeset('dummy' => watcher)
      @socket.should_receive(:servers) do
        ['a', 'b', 'c'].map { |name| new_mock_server('dummy', name) }
      end
      watcher = ProxyMgr::Watcher::Dummy.new('dummy', {}, @sm)
      watcher.servers = ['a', 'b']
      changeset = @updater.produce_changeset('dummy' => watcher)
      changeset.disable.should == {'dummy' => ['c']}
      changeset.restart_needed?.should == false
    end

    it 'enables servers if they are down and added' do
      @socket.should_receive(:servers) { [] }
      watcher = ProxyMgr::Watcher::Dummy.new('dummy', {}, @sm)
      watcher.servers = []
      @updater.produce_changeset('dummy' => watcher)
      @socket.should_receive(:servers) do
        s = ['a', 'b'].map { |name| new_mock_server('dummy', name) }
        s << new_mock_server('dummy', 'c', 'MAINT')
      end
      watcher = ProxyMgr::Watcher::Dummy.new('dummy', {}, @sm)
      watcher.servers = ['a', 'b', 'c']
      changeset = @updater.produce_changeset('dummy' => watcher)
      changeset.enable.should == {'dummy' => ['c']}
      changeset.restart_needed?.should == false
    end

    it 'requires restart if a backend is added' do
      @socket.should_receive(:servers) { [] }
      watcher = double(ProxyMgr::Watcher::Base)
      watcher.should_receive(:servers) { ['a', 'b'] }
      changeset = @updater.produce_changeset('dummy' => watcher)
      changeset.restart_needed?.should == true
    end

    it 'requires a restart if a server has not already been added/is disabled' do
      @socket.stub(:servers) do
        ['a', 'b'].map do |name|
          new_mock_server('dummy', name)
        end
      end
      watcher = double(ProxyMgr::Watcher::Base)
      watcher.should_receive(:servers) { ['a', 'b'] }
      changeset = @updater.produce_changeset('dummy' => watcher)
      watcher.should_receive(:servers) { ['a', 'b', 'c'] }
      changeset = @updater.produce_changeset('dummy' => watcher)
      changeset.restart_needed?.should == true
    end

    it 'requires restart if a backend is deleted' do
      @socket.stub(:servers) do
        ['a', 'b'].map do |name|
          new_mock_server('dummy', name)
        end
        ['c', 'd'].map do |name|
          new_mock_server('dummy2', name)
        end
      end
      watcher1 = ProxyMgr::Watcher::Dummy.new('dummy', {}, @sm).tap do |w|
        w.servers = ['a', 'b']
      end
      watcher2 = ProxyMgr::Watcher::Dummy.new('dummy2', {}, @sm).tap do |w|
        w.servers = ['c', 'd']
      end
      @updater.produce_changeset('dummy'  => watcher1,
                                 'dummy2' => watcher2)
      changeset = @updater.produce_changeset('dummy' => watcher1)
      changeset.restart_needed?.should == true
    end

    it 'requires restarting if listen_options is changed' do
      @socket.should_receive(:servers) { [] }
      watcher = ProxyMgr::Watcher::Dummy.new('dummy', {}, @sm)
      watcher.servers = ['a']
      @updater.produce_changeset('dummy' => watcher)
      @socket.should_receive(:servers) { [new_mock_server('dummy', 'a')] }
      watcher = ProxyMgr::Watcher::Dummy.new('dummy', {'listen_options' => ['test option']}, @sm)
      watcher.servers = ['a']
      changeset = @updater.produce_changeset('dummy' => watcher)
      changeset.restart_needed?.should == true
    end
  end
end
