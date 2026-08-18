require 'test_helper'

class TestEndpointsCreateVendor < Minitest::Test
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

  def test_raises_argument_error_when_vendor_is_not_a_model_vendor
    assert_raises(ArgumentError) { IntacctRest::Endpoints::CreateVendor.call(vendor: { id: 'V-00014' }) }
  end

  def test_call_returns_success_result_with_default_result_fields
    stub_token_request
    stub_request(:post, @vendor_url)
      .to_return(status: 201, body: { 'ia::result' => { 'key' => '111', 'href' => '/x/111', 'id' => 'V-00014' } }.to_json)

    result = IntacctRest::Endpoints::CreateVendor.call(vendor: @vendor)

    assert result.success?
    assert_same @vendor, result.model
    assert_equal '111', @vendor.key
  end

  def test_raises_api_error_when_an_expected_result_field_is_missing
    stub_token_request
    stub_request(:post, @vendor_url)
      .to_return(status: 201, body: { 'ia::result' => { 'key' => '111' } }.to_json) # no href

    error = assert_raises(IntacctRest::ApiError) do
      IntacctRest::Endpoints::CreateVendor.call(vendor: @vendor, results: %i[id key href])
    end

    assert_includes error.message, 'href'
  end

  def test_custom_results_list_only_checks_requested_fields
    stub_token_request
    stub_request(:post, @vendor_url)
      .to_return(status: 201, body: { 'ia::result' => { 'key' => '111' } }.to_json) # no href, no id

    result = IntacctRest::Endpoints::CreateVendor.call(vendor: @vendor, results: %i[key])

    assert result.success?
  end

  def test_failed_result_skips_result_field_verification
    stub_token_request
    stub_request(:post, @vendor_url)
      .to_return(status: 400, body: { 'ia::result' => { 'ia::error' => { 'message' => 'bad' } } }.to_json)

    result = IntacctRest::Endpoints::CreateVendor.call(vendor: @vendor)

    assert result.failed?
  end

  private

  def stub_token_request
    token_url = "#{IntacctRest.configuration.base_url}#{IntacctRest.configuration.token_path}"
    stub_request(:post, token_url)
      .to_return(status: 200, body: { access_token: 'tok-1', expires_in: 3600 }.to_json)
  end
end
