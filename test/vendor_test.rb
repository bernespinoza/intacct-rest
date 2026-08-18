require 'test_helper'

class TestVendor < Minitest::Test
  # A "final user" model subclass, adding its own validation on top of
  # Model::Vendor's built-in ones — proves IntacctRest::Vendor.call treats
  # any Model::Vendor subclass instance as valid input, not just the base
  # class.
  class CustomVendor < IntacctRest::Model::Vendor
    validate :presence, %i[tax_id]
  end

  def setup
    IntacctRest.reset
    IntacctRestTestConfig.apply
    @vendor_url = "#{IntacctRest.configuration.base_url}#{IntacctRest::Vendor::INTACCT_OBJECT}"
  end

  def teardown
    super
    IntacctRest.reset
  end

  def test_payload_uses_camel_case_json_keys
    model = IntacctRest::Model::Vendor.new(id: 'V-00014', name: 'NCS, Inc.', is_on_hold: false)

    assert_equal(
      { 'id' => 'V-00014', 'name' => 'NCS, Inc.', 'isOnHold' => false },
      IntacctRest::Vendor.payload(model)
    )
  end

  def test_payload_omits_unset_fields
    model = IntacctRest::Model::Vendor.new(id: 'V-00014', name: 'NCS, Inc.')

    assert_equal({ 'id' => 'V-00014', 'name' => 'NCS, Inc.' }, IntacctRest::Vendor.payload(model))
  end

  def test_payload_merges_custom_fields
    model = IntacctRest::Model::Vendor.new(id: 'V-00014', name: 'NCS, Inc.',
                                            custom_fields: { 'preferredCourier__c' => 'UPS' })

    assert_equal(
      { 'id' => 'V-00014', 'name' => 'NCS, Inc.', 'preferredCourier__c' => 'UPS' },
      IntacctRest::Vendor.payload(model)
    )
  end

  def test_call_raises_validation_error_without_any_http_request
    error = assert_raises(IntacctRest::ValidationError) { IntacctRest::Vendor.call(name: 'NCS, Inc.') }
    assert_includes error.message, 'id is required'
  end

  def test_call_with_hash_creates_vendor_and_returns_populated_model
    stub_token_request
    stub_request(:post, @vendor_url)
      .with(body: hash_including('id' => 'V-00014', 'name' => 'NCS, Inc.'))
      .to_return(
        status: 201,
        body: { 'ia::result' => { 'key' => '111', 'href' => '/objects/accounts-payable/vendor/111' },
                'ia::meta' => { 'totalCount' => 1 } }.to_json
      )

    vendor = IntacctRest::Vendor.call(id: 'V-00014', name: 'NCS, Inc.')

    assert_instance_of IntacctRest::Model::Vendor, vendor
    assert_equal '111', vendor.key
    assert_equal '/objects/accounts-payable/vendor/111', vendor.href
  end

  def test_call_with_model_instance_uses_given_instance
    stub_token_request
    stub_request(:post, @vendor_url)
      .to_return(status: 201, body: { 'ia::result' => { 'key' => '111', 'href' => '/x/111' } }.to_json)

    given = IntacctRest::Model::Vendor.new(id: 'V-00014', name: 'NCS, Inc.')
    result = IntacctRest::Vendor.call(given)

    assert_same given, result
    assert_equal '111', result.key
  end

  def test_call_accepts_a_model_subclass_instance
    stub_token_request
    stub_request(:post, @vendor_url)
      .with(body: hash_including('id' => 'V-00014', 'name' => 'NCS, Inc.', 'taxId' => '123-45-6789'))
      .to_return(status: 201, body: { 'ia::result' => { 'key' => '111', 'href' => '/x/111' } }.to_json)

    custom_vendor = CustomVendor.new(id: 'V-00014', name: 'NCS, Inc.', tax_id: '123-45-6789')
    result = IntacctRest::Vendor.call(custom_vendor)

    assert_same custom_vendor, result
    assert_instance_of CustomVendor, result
    assert_equal '111', result.key
  end

  def test_call_raises_validation_error_for_model_subclasss_own_validation
    custom_vendor = CustomVendor.new(id: 'V-00014', name: 'NCS, Inc.') # no tax_id

    error = assert_raises(IntacctRest::ValidationError) { IntacctRest::Vendor.call(custom_vendor) }
    assert_includes error.message, 'tax_id is required'
  end

  def test_call_backfills_id_when_not_supplied
    # id is required by default (Model::Vendor's presence validation) — a
    # company with document sequencing enabled would relax that in a
    # subclass, at which point Intacct auto-generates the id and it should
    # be backfilled here.
    auto_id_model_class = Class.new(IntacctRest::Model::Vendor) do
      def valid?
        true
      end
    end

    stub_token_request
    stub_request(:post, @vendor_url)
      .to_return(status: 201, body: { 'ia::result' => { 'key' => '111', 'href' => '/x/111', 'id' => 'AUTO-1' } }.to_json)

    vendor = IntacctRest::Vendor.call(auto_id_model_class.new(name: 'NCS, Inc.'))

    assert_equal 'AUTO-1', vendor.id
  end

  def test_call_retries_once_after_401
    stub_token_request
    stub_request(:post, @vendor_url)
      .to_return(status: 401, body: 'unauthorized')
      .then
      .to_return(status: 201, body: { 'ia::result' => { 'key' => '111', 'href' => '/x/111' } }.to_json)

    vendor = IntacctRest::Vendor.call(id: 'V-00014', name: 'NCS, Inc.')

    assert_equal '111', vendor.key
  end

  def test_call_raises_authentication_error_on_repeated_401
    stub_token_request
    stub_request(:post, @vendor_url).to_return(status: 401, body: 'unauthorized')

    assert_raises(IntacctRest::AuthenticationError) do
      IntacctRest::Vendor.call(id: 'V-00014', name: 'NCS, Inc.')
    end
  end

  def test_call_raises_api_error_on_http_failure
    stub_token_request
    stub_request(:post, @vendor_url).to_return(status: 500, body: 'boom')

    assert_raises(IntacctRest::ApiError) do
      IntacctRest::Vendor.call(id: 'V-00014', name: 'NCS, Inc.')
    end
  end

  def test_call_raises_response_parse_error_on_invalid_json
    stub_token_request
    stub_request(:post, @vendor_url).to_return(status: 201, body: 'not json')

    assert_raises(IntacctRest::ResponseParseError) do
      IntacctRest::Vendor.call(id: 'V-00014', name: 'NCS, Inc.')
    end
  end

  private

  def stub_token_request
    token_url = "#{IntacctRest.configuration.base_url}#{IntacctRest.configuration.token_path}"
    stub_request(:post, token_url)
      .to_return(status: 200, body: { access_token: 'tok-1', expires_in: 3600 }.to_json)
  end
end
