require 'test_helper'

class TestIntacctRest < Minitest::Test
  def setup
    @client = IntacctRest
  end

  def teardown
    super
    IntacctRest.reset
  end

  def test_configure_client_id
    @client.configure do |config|
      assert_respond_to config, :client_id=
    end
  end

  def test_configure_client_secret
    @client.configure do |config|
      assert_respond_to config, :client_secret=
    end
  end

  def test_configure_username
    @client.configure do |config|
      assert_respond_to config, :username=
    end
  end
end
