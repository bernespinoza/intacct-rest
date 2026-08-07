require 'test_helper'

class TestConfiguration < Minitest::Test
  def setup
    @configuration = IntacctRest::Configuration.new
  end

  def test_client_id
    assert_nil @configuration.client_id
  end

  def test_client_secret
    assert_nil @configuration.client_secret
  end

  def test_username
    assert_nil @configuration.username
  end

  def test_default_base_url
    assert_equal 'https://api.intacct.com/ia/api/v1', @configuration.base_url
  end

  def test_default_token_path
    assert_equal '/oauth2/token', @configuration.token_path
  end

  def test_default_query_path
    assert_equal '/services/core/query', @configuration.query_path
  end

  def test_default_page_size
    assert_equal 200, @configuration.page_size
  end

  def test_default_max_pages
    assert_equal 50, @configuration.max_pages
  end

  def test_default_token_key_prefix
    assert_equal 'intacct_rest:oauth', @configuration.token_key_prefix
  end

  def test_default_token_store
    assert_instance_of IntacctRest::TokenStore::Memory, @configuration.token_store
  end

  def test_on_error_defaults_to_nil
    assert_nil @configuration.on_error
  end
end

