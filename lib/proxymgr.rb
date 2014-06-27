require 'proxymgr/service_manager'
require 'proxymgr/config'
require 'proxymgr/sink'
require 'proxymgr/process_manager'
require 'proxymgr/watcher'

module ProxyMgr
  class << self
    attr_accessor :logger
  end
end
