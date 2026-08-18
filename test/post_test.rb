require 'test_helper'

class TestPost < Minitest::Test
  def setup
    IntacctRest.reset
    IntacctRestTestConfig.apply
    @vendor = IntacctRest::Model::Vendor.new(id: 'V-00014', name: 'NCS, Inc.')
    @vendor_url = "#{IntacctRest.configuration.base_url}#{@vendor.intacct_object}"
  end

  def teardown
    super
    IntacctRest.reset
  end

  def test_call_raises_validation_error_without_any_http_request
    invalid = IntacctRest::Model::Vendor.new(name: 'NCS, Inc.') # no id

    error = assert_raises(IntacctRest::ValidationError) { IntacctRest::Post.call(invalid) }
    assert_includes error.message, 'id is required'
  end

  def test_call_returns_success_result_and_applies_it_to_the_model
    stub_token_request
    stub_request(:post, @vendor_url)
      .with(body: hash_including('id' => 'V-00014', 'name' => 'NCS, Inc.'))
      .to_return(
        status: 201,
        body: { 'ia::result' => { 'key' => '111', 'href' => '/objects/accounts-payable/vendor/111' } }.to_json
      )

    result = IntacctRest::Post.call(@vendor)

    assert_instance_of IntacctRest::Result::Success, result
    assert result.success?
    refute result.failed?
    assert_same @vendor, result.model
    assert_equal '111', @vendor.key
    assert_equal '/objects/accounts-payable/vendor/111', @vendor.href
  end

  def test_call_returns_error_result_without_raising_on_non_2xx
    stub_token_request
    stub_request(:post, @vendor_url)
      .to_return(status: 400, body: { 'ia::result' => { 'ia::error' => { 'message' => 'bad request' } } }.to_json)

    result = IntacctRest::Post.call(@vendor)

    assert_instance_of IntacctRest::Result::Error, result
    refute result.success?
    assert result.failed?
    assert_equal '400', result.code
    assert_equal 'bad request', result.error['message']
    assert_nil @vendor.key # apply_result never called on failure
  end

  def test_call_retries_once_after_401
    stub_token_request
    stub_request(:post, @vendor_url)
      .to_return(status: 401, body: 'unauthorized')
      .then
      .to_return(status: 201, body: { 'ia::result' => { 'key' => '111', 'href' => '/x/111' } }.to_json)

    result = IntacctRest::Post.call(@vendor)

    assert result.success?
  end

  def test_call_raises_authentication_error_on_repeated_401
    stub_token_request
    stub_request(:post, @vendor_url).to_return(status: 401, body: 'unauthorized')

    assert_raises(IntacctRest::AuthenticationError) { IntacctRest::Post.call(@vendor) }
  end

  def test_call_raises_response_parse_error_on_invalid_json
    stub_token_request
    stub_request(:post, @vendor_url).to_return(status: 201, body: 'not json')

    assert_raises(IntacctRest::ResponseParseError) { IntacctRest::Post.call(@vendor) }
  end

  private

  def stub_token_request
    token_url = "#{IntacctRest.configuration.base_url}#{IntacctRest.configuration.token_path}"
    stub_request(:post, token_url)
      .to_return(status: 200, body: { access_token: 'tok-1', expires_in: 3600 }.to_json)
  end
end
