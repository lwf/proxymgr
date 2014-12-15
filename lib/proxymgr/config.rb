module ProxyMgr
  class Config
    require 'yaml'
    require 'erb'

    DEFAULTS = {
      'haproxy' => {
        'path'        => 'haproxy',
        'config_path' => '/etc/haproxy/haproxy.cfg',
        'global'      => ['maxconn 4096',
                          'log  127.0.0.1 local0',
                          'log  127.0.0.1 local1 notice'],
        'defaults'    => ['log global',
                          'option dontlognull',
                          'maxconn 2000',
                          'retries 3',
                          'timeout connect 5s',
                          'timeout client 1m',
                          'timeout server 1m',
                          'option redispatch',
                          'balance roundrobin']
      }
    }

    VALIDATORS = {
      'haproxy' => {
        'path' => :executable,
        'config_path' => :fullpath,
        'socket_path' => :fullpath,
        'global'      => :array_of_strings,
        'default'     => :array_of_strings
      },
      'service_config' => {
        'type' => :svconfig
      }
    }

    def initialize(file)
      data    = ERB.new(File.read(file)).result(binding)
      @config = YAML.load(data) || {}

      merge_defaults!
      validate_config
    end

    def [](key)
      @config[key]
    end

    private

    def merge_defaults!
      DEFAULTS.each do |key, value|
        if @config[key]
          @config[key] = value.merge(@config[key])
        else
          @config[key] = value
        end
      end
    end

    def validate_config
      validate_haproxy
      validate_svconfig
    end

    def validate_svconfig
      validate_hash(@config['service_config'], VALIDATORS['service_config'])
    end

    def validate_haproxy
      validate_hash(@config['haproxy'], VALIDATORS['haproxy'])
    end

    def validate_hash(data, validators)
      fail ConfigException.new "not a hash" unless data.is_a? Hash

      data.each do |key, value|
        Validators.send(validators[key], key, value) if validators[key]
      end
    end

    module Validators
      class << self
        def fullpath(key, value)
          should("#{key} should be a valid full path") { value =~ /^\// }
        end

        def executable(key, exe)
          should("#{key} should be an executable") do
            if exe =~ /^\//
              File.executable? exe
            else
              ENV['PATH'].split(':').find do |e|
                File.executable? File.join(e, exe)
              end
            end
          end
        end

        def array_of_strings(key, ary)
          ary.each_with_index do |value, i|
            should("#{key}[#{i}] should be a string") do
              value.is_a? String
            end
          end
        end

        def svconfig(key, type)
          should("#{key} should be a service config implementation") do
            begin
              ServiceConfig.const_get(type.capitalize)
            rescue NameError
              false
            end
          end
        end

        private

        def should(reason = nil, &blk)
          fail ConfigException.new(reason) unless blk.call
        end
      end
    end

    class ConfigException < Exception; end
  end
end
