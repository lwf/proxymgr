require 'spec_helper'

describe ProxyMgr::ZK::Client do
  before do
    @client  = ProxyMgr::ZK::Client.new('localhost', {}, FakeZookeeper)
    @client.connect
    @fake_zk = @client.instance_variable_get(:@zookeeper)
  end

  it 'tries to reconnect when sessions have expired' do
    expect(@fake_zk).to receive(:reopen)
    @fake_zk.expired!
  end
end
