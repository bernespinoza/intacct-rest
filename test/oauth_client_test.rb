require 'test_helper'

class TestOauthClient < Minitest::Test
  def setup
    IntacctRest.reset
    IntacctRestTestConfig.apply
    @token_url = "#{IntacctRest.configuration.base_url}#{IntacctRest.configuration.token_path}"
    @oauth = IntacctRest::OauthClient.new
  end

  def teardown
    super
    IntacctRest.reset
  end

  def test_access_token_fetches_client_credentials_when_uncached
    stub_request(:post, @token_url)
      .with { |req| JSON.parse(req.body)['grant_type'] == 'client_credentials' }
      .to_return(status: 200, body: { access_token: 'tok-1', expires_in: 3600, refresh_token: 'ref-1' }.to_json)

    assert_equal 'tok-1', @oauth.access_token
  end

  def test_access_token_returns_cached_token_without_new_request
    IntacctRest.configuration.token_store.write('intacct_rest:oauth:access_token', 'cached-tok')

    assert_equal 'cached-tok', @oauth.access_token
    assert_not_requested :post, @token_url
  end

  def test_refresh_access_token_uses_refresh_grant_when_available
    IntacctRest.configuration.token_store.write('intacct_rest:oauth:refresh_token', 'ref-1')
    stub_request(:post, @token_url)
      .with { |req| JSON.parse(req.body)['grant_type'] == 'refresh_token' }
      .to_return(status: 200, body: { access_token: 'tok-2', expires_in: 3600 }.to_json)

    assert_equal 'tok-2', @oauth.refresh_access_token
  end

  def test_refresh_access_token_falls_back_to_client_credentials_when_refresh_fails
    IntacctRest.configuration.token_store.write('intacct_rest:oauth:refresh_token', 'stale-ref')
    stub_request(:post, @token_url)
      .with { |req| JSON.parse(req.body)['grant_type'] == 'refresh_token' }
      .to_return(status: 401, body: 'invalid_grant')
    stub_request(:post, @token_url)
      .with { |req| JSON.parse(req.body)['grant_type'] == 'client_credentials' }
      .to_return(status: 200, body: { access_token: 'tok-3', expires_in: 3600 }.to_json)

    assert_equal 'tok-3', @oauth.refresh_access_token
  end

  def test_refresh_access_token_fetches_when_no_refresh_token_stored
    stub_request(:post, @token_url)
      .with { |req| JSON.parse(req.body)['grant_type'] == 'client_credentials' }
      .to_return(status: 200, body: { access_token: 'tok-4', expires_in: 3600 }.to_json)

    assert_equal 'tok-4', @oauth.refresh_access_token
  end

  def test_raises_authentication_error_on_non_success
    stub_request(:post, @token_url).to_return(status: 500, body: 'boom')

    assert_raises(IntacctRest::AuthenticationError) { @oauth.access_token }
  end

  def test_on_error_receives_token_failure_with_safe_context_only
    calls = record_on_error
    stub_request(:post, @token_url).to_return(status: 500, body: 'boom')

    error = assert_raises(IntacctRest::AuthenticationError) { @oauth.access_token }

    assert_equal [[error, { operation: :token_request, path: '/oauth2/token', grant_type: 'client_credentials' }]], calls
    secrets = %w[test-client-id test-client-secret test-username]
    assert_empty calls.first.last.values & secrets
  end

  def test_on_error_receives_response_parse_error_from_token_endpoint
    calls = record_on_error
    stub_request(:post, @token_url).to_return(status: 200, body: 'not json')

    error = assert_raises(IntacctRest::ResponseParseError) { @oauth.access_token }

    assert_equal [[error, { operation: :token_request, path: '/oauth2/token', grant_type: 'client_credentials' }]], calls
  end

  def test_on_error_is_not_called_when_a_failed_refresh_recovers
    calls = record_on_error
    IntacctRest.configuration.token_store.write('intacct_rest:oauth:refresh_token', 'stale-ref')
    stub_request(:post, @token_url)
      .with { |req| JSON.parse(req.body)['grant_type'] == 'refresh_token' }
      .to_return(status: 401, body: 'invalid_grant')
    stub_request(:post, @token_url)
      .with { |req| JSON.parse(req.body)['grant_type'] == 'client_credentials' }
      .to_return(status: 200, body: { access_token: 'tok-3', expires_in: 3600 }.to_json)

    assert_equal 'tok-3', @oauth.refresh_access_token
    assert_empty calls
  end

  def test_on_error_is_called_once_when_refresh_and_fallback_both_fail
    calls = record_on_error
    IntacctRest.configuration.token_store.write('intacct_rest:oauth:refresh_token', 'stale-ref')
    stub_request(:post, @token_url).to_return(status: 401, body: 'invalid_grant')

    error = assert_raises(IntacctRest::AuthenticationError) { @oauth.refresh_access_token }

    assert_equal [[error, { operation: :token_request, path: '/oauth2/token', grant_type: 'client_credentials' }]], calls
  end

  private

  def record_on_error
    calls = []
    IntacctRest.configuration.on_error = ->(error, context:) { calls << [error, context] }
    calls
  end
end
