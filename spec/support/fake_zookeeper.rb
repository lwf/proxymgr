class FakeZookeeper
  require 'zookeeper'

  def initialize(server, heartbeat, watcher)
    @server    = server
    @heartbeat = heartbeat
    @watcher   = watcher
  end

  def reopen
    connected!
  end

  def expired!
    disconnected!
    call_session(Zookeeper::ZOO_EXPIRED_SESSION_STATE)
  end

  def disconnected!
    call_session(Zookeeper::ZOO_CONNECTING_STATE)
  end

  def connected!
    call_session(Zookeeper::ZOO_CONNECTED_STATE)
  end

  private

  def call_session(state)
    @watcher.call(zoo_session_event(state))
  end

  def zoo_session_event(state)
    {:state => state}
  end
end
