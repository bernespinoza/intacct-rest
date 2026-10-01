require 'test_helper'

class TestObjects < Minitest::Test
  def setup
    IntacctRest.reset
    IntacctRestTestConfig.apply
    @base_url = IntacctRest.configuration.base_url
    @objects = IntacctRest::Objects.new
  end

  def teardown
    super
    IntacctRest.reset
  end

  def test_list_returns_items
    stub_token_request
    stub_request(:get, "#{@base_url}/objects/accounts-receivable/invoice")
      .to_return(status: 200, body: { 'ia::result' => [{ 'key' => '1' }, { 'key' => '2' }] }.to_json)

    assert_equal [{ 'key' => '1' }, { 'key' => '2' }], @objects.list('accounts-receivable/invoice')
  end

  def test_list_returns_empty_array_when_missing_result
    stub_token_request
    stub_request(:get, "#{@base_url}/objects/accounts-receivable/invoice")
      .to_return(status: 200, body: {}.to_json)

    assert_equal [], @objects.list('accounts-receivable/invoice')
  end

  def test_find_returns_single_record
    stub_token_request
    stub_request(:get, "#{@base_url}/objects/accounts-receivable/invoice/42")
      .to_return(status: 200, body: { 'ia::result' => { 'key' => '42', 'state' => 'paid' } }.to_json)

    assert_equal({ 'key' => '42', 'state' => 'paid' }, @objects.find('accounts-receivable/invoice', '42'))
  end

  def test_find_retries_once_after_401
    stub_token_request
    stub_request(:get, "#{@base_url}/objects/accounts-receivable/invoice/42")
      .to_return(status: 401, body: 'unauthorized')
      .then
      .to_return(status: 200, body: { 'ia::result' => { 'key' => '42' } }.to_json)

    assert_equal({ 'key' => '42' }, @objects.find('accounts-receivable/invoice', '42'))
  end

  def test_raises_authentication_error_on_repeated_401
    stub_token_request
    stub_request(:get, "#{@base_url}/objects/accounts-receivable/invoice/42").to_return(status: 401, body: 'nope')

    assert_raises(IntacctRest::AuthenticationError) { @objects.find('accounts-receivable/invoice', '42') }
  end

  def test_raises_api_error_on_http_failure
    stub_token_request
    stub_request(:get, "#{@base_url}/objects/accounts-receivable/invoice/42").to_return(status: 500, body: 'boom')

    assert_raises(IntacctRest::ApiError) { @objects.find('accounts-receivable/invoice', '42') }
  end

  def test_raises_response_parse_error_on_invalid_json
    stub_token_request
    stub_request(:get, "#{@base_url}/objects/accounts-receivable/invoice/42").to_return(status: 200, body: 'not json')

    assert_raises(IntacctRest::ResponseParseError) { @objects.find('accounts-receivable/invoice', '42') }
  end

  def test_on_error_receives_api_error_on_http_failure
    calls = record_on_error
    stub_token_request
    stub_request(:get, "#{@base_url}/objects/accounts-receivable/invoice/42").to_return(status: 500, body: 'boom')

    error = assert_raises(IntacctRest::ApiError) { @objects.find('accounts-receivable/invoice', '42') }

    assert_equal [[error, { operation: :api_request, path: '/objects/accounts-receivable/invoice/42', http_status: '500' }]],
                 calls
  end

  def test_on_error_receives_api_error_on_ia_error_payload
    calls = record_on_error
    stub_token_request
    stub_request(:get, "#{@base_url}/objects/accounts-receivable/invoice/42")
      .to_return(status: 200, body: { 'ia::error' => { 'message' => 'bad' } }.to_json)

    error = assert_raises(IntacctRest::ApiError) { @objects.find('accounts-receivable/invoice', '42') }

    assert_equal [[error, { operation: :api_request, path: '/objects/accounts-receivable/invoice/42', http_status: '200' }]],
                 calls
  end

  def test_on_error_receives_authentication_error_once_on_repeated_401
    calls = record_on_error
    stub_token_request
    stub_request(:get, "#{@base_url}/objects/accounts-receivable/invoice/42").to_return(status: 401, body: 'nope')

    error = assert_raises(IntacctRest::AuthenticationError) { @objects.find('accounts-receivable/invoice', '42') }

    assert_equal [[error, { operation: :api_request, path: '/objects/accounts-receivable/invoice/42', http_status: '401' }]],
                 calls
  end

  def test_on_error_receives_response_parse_error_with_its_cause
    calls = record_on_error
    stub_token_request
    stub_request(:get, "#{@base_url}/objects/accounts-receivable/invoice/42").to_return(status: 200, body: 'not json')

    error = assert_raises(IntacctRest::ResponseParseError) { @objects.find('accounts-receivable/invoice', '42') }

    assert_equal [[error, { operation: :api_request, path: '/objects/accounts-receivable/invoice/42' }]], calls
    assert_kind_of JSON::ParserError, calls.first.first.cause
    refute_nil calls.first.first.backtrace
  end

  def test_nil_on_error_raises_the_same_error
    stub_token_request
    stub_request(:get, "#{@base_url}/objects/accounts-receivable/invoice/42").to_return(status: 500, body: 'boom')

    error = assert_raises(IntacctRest::ApiError) { @objects.find('accounts-receivable/invoice', '42') }

    assert_equal 'HTTP 500 requesting /objects/accounts-receivable/invoice/42', error.message
    assert_equal '500', error.http_status
    assert_equal 'boom', error.body
  end

  def test_raising_on_error_does_not_change_the_error
    stub_token_request
    stub_request(:get, "#{@base_url}/objects/accounts-receivable/invoice/42").to_return(status: 500, body: 'boom')
    without_hook = assert_raises(IntacctRest::ApiError) { @objects.find('accounts-receivable/invoice', '42') }

    IntacctRest.configuration.on_error = ->(_error, context:) { raise 'hook failed' }
    with_hook = assert_raises(IntacctRest::ApiError) { @objects.find('accounts-receivable/invoice', '42') }

    assert_equal without_hook.message, with_hook.message
    assert_equal without_hook.http_status, with_hook.http_status
    assert_equal without_hook.body, with_hook.body
    assert_equal gem_frames(without_hook), gem_frames(with_hook)
  end

  def test_on_error_accepts_an_optional_context_keyword
    calls = []
    IntacctRest.configuration.on_error = lambda do |error, context: {}|
      calls << [error.class, context[:http_status]]
    end
    stub_token_request
    stub_request(:get, "#{@base_url}/objects/accounts-receivable/invoice/42").to_return(status: 500, body: 'boom')

    assert_raises(IntacctRest::ApiError) { @objects.find('accounts-receivable/invoice', '42') }

    assert_equal [[IntacctRest::ApiError, '500']], calls
  end

  private

  def record_on_error
    calls = []
    IntacctRest.configuration.on_error = ->(error, context:) { calls << [error, context] }
    calls
  end

  def gem_frames(error)
    error.backtrace.grep(%r{lib/intacct_rest/})
  end

  def stub_token_request
    token_url = "#{IntacctRest.configuration.base_url}#{IntacctRest.configuration.token_path}"
    stub_request(:post, token_url).to_return(status: 200, body: { access_token: 'tok-1', expires_in: 3600 }.to_json)
  end
end
