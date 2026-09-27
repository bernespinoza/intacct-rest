require 'test_helper'

class TestPatch < Minitest::Test
  def setup
    IntacctRest.reset
    IntacctRestTestConfig.apply
    @vendor = IntacctRest::Model::Vendor.new(key: '111', billing_type: 'balanceForward')
    @vendor_url = "#{IntacctRest.configuration.base_url}#{@vendor.intacct_object}/111"
  end

  def teardown
    super
    IntacctRest.reset
  end

  def test_call_raises_validation_error_without_any_http_request
    invalid = IntacctRest::Model::Vendor.new(billing_type: 'balanceForward') # no key

    error = assert_raises(IntacctRest::ValidationError) { IntacctRest::Patch.call(invalid) }
    assert_includes error.message, 'key is required'
  end

  def test_call_patches_the_record_with_only_the_set_fields
    stub_token_request
    stub_request(:patch, @vendor_url)
      .with(body: { 'billingType' => 'balanceForward' })
      .to_return(
        status: 200,
        body: { 'ia::result' => { 'key' => '111', 'id' => 'V-00014',
                                  'href' => '/objects/accounts-payable/vendor/111' } }.to_json
      )

    result = IntacctRest::Patch.call(@vendor)

    assert_instance_of IntacctRest::Result::Success, result
    assert result.success?
    assert_same @vendor, result.model
    assert_equal '/objects/accounts-payable/vendor/111', @vendor.href
    assert_equal 'V-00014', @vendor.id
  end

  def test_call_does_not_send_readonly_id
    @vendor.id = 'V-00014'
    stub_token_request
    stub_request(:patch, @vendor_url)
      .with(body: { 'billingType' => 'balanceForward' })
      .to_return(status: 200, body: { 'ia::result' => { 'key' => '111' } }.to_json)

    assert IntacctRest::Patch.call(@vendor).success?
  end

  def test_call_returns_error_result_without_raising_on_non_2xx
    stub_token_request
    stub_request(:patch, @vendor_url)
      .to_return(status: 400, body: { 'ia::result' => { 'ia::error' => { 'message' => 'bad request' } } }.to_json)

    result = IntacctRest::Patch.call(@vendor)

    assert_instance_of IntacctRest::Result::Error, result
    assert result.failed?
    assert_equal '400', result.code
    assert_equal 'bad request', result.error['message']
    assert_nil @vendor.href # apply_result never called on failure
  end

  def test_call_retries_once_after_401
    stub_token_request
    stub_request(:patch, @vendor_url)
      .to_return(status: 401, body: 'unauthorized')
      .then
      .to_return(status: 200, body: { 'ia::result' => { 'key' => '111', 'href' => '/x/111' } }.to_json)

    assert IntacctRest::Patch.call(@vendor).success?
  end

  def test_call_raises_authentication_error_on_repeated_401
    stub_token_request
    stub_request(:patch, @vendor_url).to_return(status: 401, body: 'unauthorized')

    assert_raises(IntacctRest::AuthenticationError) { IntacctRest::Patch.call(@vendor) }
  end

  def test_call_raises_response_parse_error_on_invalid_json
    stub_token_request
    stub_request(:patch, @vendor_url).to_return(status: 200, body: 'not json')

    assert_raises(IntacctRest::ResponseParseError) { IntacctRest::Patch.call(@vendor) }
  end

  private

  def stub_token_request
    token_url = "#{IntacctRest.configuration.base_url}#{IntacctRest.configuration.token_path}"
    stub_request(:post, token_url)
      .to_return(status: 200, body: { access_token: 'tok-1', expires_in: 3600 }.to_json)
  end
end
