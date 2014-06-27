module ProxyMgr
  class Config
    def initialize(manager)
      @manager = manager
      @manager.add_service("test_service", {"port" => 8080,
                                               "type" => "dns",
                                               "backends" => [{"name" => "google.com",
                                                               "port" => "80"}]})
      @manager.add_service("test_service2",  {"file" => "/tmp/lol",
                                              "type" => "file"})
    end
  end
end
