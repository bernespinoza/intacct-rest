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
    invalid = IntacctRest::Model::Bill.new(billing_type: 'balanceForward') # no key

    error = assert_raises(IntacctRest::ValidationError) { IntacctRest::Delete.call(invalid) }
    assert_includes error.message, 'key is required'
  end

  def test_call_deletes_the_record
    stub_token_request
    stub_request(:delete, @vendor_url)
      .to_return(status: 200, body: ''.to_json)

    result = IntacctRest::Delete.call(@vendor)

    assert_instance_of IntacctRest::Result::Success, result
    assert result.success?
  end


  def test_call_returns_error_result_without_raising_on_non_2xx
    stub_token_request
    stub_request(:delete, @vendor_url)
      .to_return(status: 400, body: {
        'ia::result' => {
          'ia::error' => {
          'code' => 'invalidRequest',
          'message' => 'bad request',
          'errorId' => 'REST-1028'
          }
        },
        'ia::meta' => {
          'totalCount' => 1,
          'totalSuccess' => 0,
          'totalError' => 1
        }
      }.to_json)

    result = IntacctRest::Delete.call(@vendor)

    assert_instance_of IntacctRest::Result::Error, result
    assert result.failed?
    assert_equal '400', result.code
    assert_equal 'bad request', result.error['message']
  end

  def test_call_retries_once_after_401
    stub_token_request
    stub_request(:delete, @vendor_url)
      .to_return(status: 401, body: 'unauthorized')
      .then
      .to_return(status: 200, body: ''.to_json)

    assert IntacctRest::Delete.call(@vendor).success?
  end

  def test_call_raises_authentication_error_on_repeated_401
    stub_token_request
    stub_request(:delete, @vendor_url).to_return(status: 401, body: 'unauthorized')

    assert_raises(IntacctRest::AuthenticationError) { IntacctRest::Delete.call(@vendor) }
  end

  private

  def stub_token_request
    token_url = "#{IntacctRest.configuration.base_url}#{IntacctRest.configuration.token_path}"
    stub_request(:post, token_url)
      .to_return(status: 200, body: { access_token: 'tok-1', expires_in: 3600 }.to_json)
  end
end
