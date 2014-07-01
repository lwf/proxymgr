require 'proxymgr/logging'
require 'proxymgr/config'
require 'proxymgr/callbacks'
require 'proxymgr/zkclient'
require 'proxymgr/service_manager'
require 'proxymgr/service_config'
require 'proxymgr/process_manager'
require 'proxymgr/haproxy'
require 'proxymgr/sink'
require 'proxymgr/watcher'

module ProxyMgr
  def self.root
    File.expand_path(File.join(__FILE__, '..', '..'))
  end

  def self.template_dir
    File.join(root, 'etc')
  end
end
