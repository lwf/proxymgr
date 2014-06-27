module ProxyMgr
  class Config
    def initialize(manager)
      @manager = manager
      @manager.set_services("test_service" => {"port" => 8080,
                                               "type" => "dns",
                                               "backends" => [{"name" => "google.com",
                                                               "port" => "80"}]},
                            "test_service2" => {"file" => "/tmp/lol",
                                                "type" => "file"})
    end
  end
end
