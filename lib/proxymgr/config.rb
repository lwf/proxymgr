module ProxyMgr
  class Config
    require 'yaml'

    DEFAULTS = {
      'haproxy' => {
        'path'        => 'haproxy',
        'config_path' => '/etc/haproxy/haproxy.cfg',
        'socket_path' => '/var/lib/haproxy.sock'
      }
    }

    VALIDATORS = {
      'haproxy' => {
        'path' => :executable,
        'config_path' => :fullpath,
        'socket_path' => :fullpath
      }
    }

    def initialize(file)
      data    = interpolate_variables(File.read(file))
      @config = YAML.load(data) || {}

      merge_defaults!
      validate_config
    end

    def [](key)
      @config[key]
    end

    private

    def interpolate_variables(data)
      data.gsub(/\{\{\s+?(.*)\s+?\}\}/) do |v| 
        if e = ENV[$1]
          e
        else
          raise ConfigException.new "Environment variable #{$1} is not set"
        end
      end
    end

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
    end

    def validate_haproxy
      validate_hash(@config['haproxy'], VALIDATORS['haproxy'])
    end

    def validate_hash(data, validators)
      data.each do |key, value|
        if v = validators[key]
          Validators.send(v, key, value)
        end
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
              ENV['PATH'].split(':').find { |e| File.executable? File.join(e, exe) }
            end
          end
        end

        private

        def should(reason = nil, &blk)
          unless blk.call
            raise ConfigException.new(reason)
          end
        end
      end
    end

    class ConfigException < Exception; end
  end
end
