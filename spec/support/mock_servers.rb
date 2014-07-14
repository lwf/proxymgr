module MockServers
  def new_mock_server(backend, name, status = nil)
    ProxyMgr::Haproxy::Server.new(nil, {'pxname' => backend,
                                        'svname' => name,
                                        'status' => status})
  end
end
