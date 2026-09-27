require 'test_helper'

class TestEndpointsUpdateVendor < Minitest::Test
  def setup
    IntacctRest.reset
    IntacctRestTestConfig.apply
    @vendor = IntacctRest::Model::Vendor.new(key: '111', credit_limit: 10_000)
    @vendor_url = "#{IntacctRest.configuration.base_url}#{@vendor.intacct_object}/111"
  end

  def teardown
    super
    IntacctRest.reset
  end

  def test_raises_argument_error_when_vendor_is_not_a_model_vendor
    assert_raises(ArgumentError) { IntacctRest::Endpoints::UpdateVendor.call(vendor: { key: '111' }) }
  end

  def test_raises_validation_error_without_key
    vendor = IntacctRest::Model::Vendor.new(credit_limit: 10_000)

    assert_raises(IntacctRest::ValidationError) { IntacctRest::Endpoints::UpdateVendor.call(vendor: vendor) }
  end

  def test_call_returns_success_result_with_default_result_fields
    stub_token_request
    stub_request(:patch, @vendor_url)
      .to_return(status: 200, body: { 'ia::result' => { 'key' => '111', 'href' => '/x/111', 'id' => 'V-00014' } }.to_json)

    result = IntacctRest::Endpoints::UpdateVendor.call(vendor: @vendor)

    assert result.success?
    assert_same @vendor, result.model
    assert_equal 'V-00014', @vendor.id
  end

  def test_sends_nested_objects_as_is
    vendor = IntacctRest::Model::Vendor.new(
      key: '111',
      term: { 'id' => 'Net 30' },
      bank_files: { 'paymentCountryCode' => 'gb', 'paymentCurrency' => 'EUR' },
      contacts: { 'payTo' => { 'id' => 'Klay Vanderbilt' } },
      contact_list: [{ 'categoryName' => 'Main Office', 'contact' => { 'id' => 'Jeffrey Post' } }]
    )
    stub_token_request
    stub_request(:patch, @vendor_url)
      .with(body: {
              'term' => { 'id' => 'Net 30' },
              'bankFiles' => { 'paymentCountryCode' => 'gb', 'paymentCurrency' => 'EUR' },
              'contacts' => { 'payTo' => { 'id' => 'Klay Vanderbilt' } },
              'contactList' => [{ 'categoryName' => 'Main Office', 'contact' => { 'id' => 'Jeffrey Post' } }]
            })
      .to_return(status: 200, body: { 'ia::result' => { 'key' => '111', 'href' => '/x/111', 'id' => 'V-00014' } }.to_json)

    assert IntacctRest::Endpoints::UpdateVendor.call(vendor: vendor).success?
  end

  def test_raises_validation_error_for_invalid_nested_object
    vendor = IntacctRest::Model::Vendor.new(key: '111', bank_files: { 'paymentCountryCode' => 'zz' })

    error = assert_raises(IntacctRest::ValidationError) { IntacctRest::Endpoints::UpdateVendor.call(vendor: vendor) }
    assert_includes error.message, 'bank_files_payment_country_code'
  end

  def test_raises_api_error_when_an_expected_result_field_is_missing
    stub_token_request
    stub_request(:patch, @vendor_url)
      .to_return(status: 200, body: { 'ia::result' => { 'key' => '111' } }.to_json) # no href

    error = assert_raises(IntacctRest::ApiError) do
      IntacctRest::Endpoints::UpdateVendor.call(vendor: @vendor, results: %i[id key href])
    end

    assert_includes error.message, 'href'
  end

  def test_custom_results_list_only_checks_requested_fields
    stub_token_request
    stub_request(:patch, @vendor_url)
      .to_return(status: 200, body: { 'ia::result' => { 'key' => '111' } }.to_json) # no href, no id

    result = IntacctRest::Endpoints::UpdateVendor.call(vendor: @vendor, results: %i[key])

    assert result.success?
  end

  def test_failed_result_skips_result_field_verification
    stub_token_request
    stub_request(:patch, @vendor_url)
      .to_return(status: 400, body: { 'ia::result' => { 'ia::error' => { 'message' => 'bad' } } }.to_json)

    result = IntacctRest::Endpoints::UpdateVendor.call(vendor: @vendor)

    assert result.failed?
  end

  private

  def stub_token_request
    token_url = "#{IntacctRest.configuration.base_url}#{IntacctRest.configuration.token_path}"
    stub_request(:post, token_url)
      .to_return(status: 200, body: { access_token: 'tok-1', expires_in: 3600 }.to_json)
  end
end
