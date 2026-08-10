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

  private

  def stub_token_request
    token_url = "#{IntacctRest.configuration.base_url}#{IntacctRest.configuration.token_path}"
    stub_request(:post, token_url).to_return(status: 200, body: { access_token: 'tok-1', expires_in: 3600 }.to_json)
  end
end
