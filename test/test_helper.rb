require 'minitest/autorun'
require 'webmock/minitest'
require 'intacct_rest'

WebMock.disable_net_connect!

module IntacctRestTestConfig
  def self.apply(config = IntacctRest.configuration)
    config.client_id     = 'test-client-id'
    config.client_secret = 'test-client-secret'
    config.username      = 'test-username'
    config
  end
end

module ResetWebMockAfterEachTest
  def teardown
    super
    WebMock.reset!
  end
end

Minitest::Test.prepend(ResetWebMockAfterEachTest)
