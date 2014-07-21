class FakeZookeeper
  require 'zookeeper'

  def initialize(server, heartbeat, watcher)
    @server    = server
    @heartbeat = heartbeat
    @watcher   = watcher

    @state     = {:children => {}}
    @watches   = {}
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

  def get(opts)
    path    = opts[:path]
    watcher = opts[:watcher]

    data = get_path(path)
    if data
      watch_path(path, watcher) if watcher
      event(data)
    else
      event(data, Zookeeper::ZNONODE)
    end
  end

  def set(opts)
    path    = opts[:path]
    data    = opts[:data]

    data = set_path(path, data)
    event = event(data)
    fire_watches(path, event) if data
    event
  end

  def create(opts)
    path    = opts[:path]
    data    = opts[:data]
    watcher = opts[:watcher]

    parts  = path.split('/')
    name   = parts.pop
    parent = File.join(*parts)

    data = create_path(name, parent, data)
    event = event(data)
    fire_watches(parent, event) if data
    watch_path(path, watcher) if watcher
    event
  end

  def get_children(opts)
    path    = opts[:path]
    watcher = opts[:watcher]

    data = get_children_path(path)
    if data
      watch_path(path, watcher) if watcher
      {:rc       => Zookeeper::ZOK,
       :children => data}
    else
      {:rc       => Zookeeper::ZNONODE}
    end
  end

  def watcher_callback(&blk)
    blk
  end

  private

  def get_path(path)
    node = resolve_node(path)
    (node[:data] || "") if node
  end

  def set_path(path, set_data)
    node = resolve_node(path)
    node[:data] = set_data if node
  end

  def watch_path(path, watcher)
    node = resolve_node(path)
    if node
      node[:watches] ||= []
      node[:watches] << watcher
    end
  end

  def create_path(name, parent, data)
    node = resolve_node(parent)
    if node
      c = node[:children] ||= {}
      n = c[name] ||= {}
      if data
        n[:data] = data
      else
        true
      end
    end
  end

  def get_children_path(path)
    node = resolve_node(path)
    node[:children] ? node[:children].keys : [] if node
  end

  def fire_watches(path, event = nil)
    node = resolve_node(path)
    node.delete(:watches).each { |w| w.call event } if node and node[:watches]
  end

  def resolve_node(path)
    parts = path.split('/')
    return @state if parts.size <= 1
    parts.shift
    leaf_name = parts.pop
    r = parts.inject(@state[:children]) do |state, comp|
      data = state[comp]
      break unless data and data[:children]
      data[:children]
    end
    r[leaf_name] if r
  end

  def call_session(state)
    @watcher.call(zoo_session_event(state))
  end

  def zoo_session_event(state)
    Event.new.tap do |e|
      e.state = state
      e.type  = state
    end
  end

  def event(data, rc = Zookeeper::ZOK)
    Event.new.tap do |e|
      e.data = data
      e.rc   = rc
    end
  end

  class Event < Struct.new(:rc, :state, :data, :type); end
end
