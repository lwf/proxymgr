module ProxyMgr
  class ServiceConfig
    def initialize(manager)
      @manager = manager
      @manager.add_service("test_service", {"port" => 8080,
                                               "type" => "dns",
                                               "backends" => [{"name" => "google.com",
                                                               "port" => "80"}]})
      @manager.add_service("test_service2",  {"path" => "/campanja/elastic/basic_vpc",
                                              "port" => 8003,
                                              "server" => "localhost:2181",
                                              "type" => "campanjazk"})
    end
  end
end
