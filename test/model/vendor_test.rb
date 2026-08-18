require 'test_helper'

class TestModelVendor < Minitest::Test
  Source = Struct.new(:id, :name, :credit_limit, :unrelated_field)

  def test_writable_attributes_are_accessible
    vendor = IntacctRest::Model::Vendor.new(id: 'V-00014', name: 'NCS, Inc.', credit_limit: 40_000)

    assert_equal 'V-00014', vendor.id
    assert_equal 'NCS, Inc.', vendor.name
    assert_equal 40_000, vendor.credit_limit
  end

  def test_custom_fields_defaults_to_empty_array
    assert_equal([], IntacctRest::Model::Vendor.new(id: 'V-00014', name: 'NCS, Inc.').custom_fields)
  end

  def test_readonly_attributes_are_writable_for_the_operation_to_populate
    vendor = IntacctRest::Model::Vendor.new(id: 'V-00014', name: 'NCS, Inc.')
    vendor.key = '111'
    vendor.href = '/objects/accounts-payable/vendor/111'

    assert_equal '111', vendor.key
    assert_equal '/objects/accounts-payable/vendor/111', vendor.href
  end

  def test_intacct_object
    assert_equal '/objects/accounts-payable/vendor', IntacctRest::Model::Vendor.new.intacct_object
  end

  def test_attributes_returns_ruby_side_hash_without_json_mapping
    vendor = IntacctRest::Model::Vendor.new(id: 'V-00014', name: 'NCS, Inc.')

    assert_equal 'V-00014', vendor.attributes[:id]
    assert_equal 'NCS, Inc.', vendor.attributes[:name]
  end

  def test_valid_with_id_and_name
    assert IntacctRest::Model::Vendor.new(id: 'V-00014', name: 'NCS, Inc.').valid?
  end

  def test_invalid_without_id
    vendor = IntacctRest::Model::Vendor.new(name: 'NCS, Inc.')

    refute vendor.valid?
    assert_includes vendor.errors, 'id is required'
  end

  def test_invalid_without_name
    vendor = IntacctRest::Model::Vendor.new(id: 'V-00014')

    refute vendor.valid?
    assert_includes vendor.errors, 'name is required'
  end

  def test_invalid_with_wrong_kind_of_attribute
    vendor = IntacctRest::Model::Vendor.new(id: 'V-00014', name: 'NCS, Inc.', credit_limit: 'lots')

    refute vendor.valid?
    assert_includes vendor.errors, 'credit_limit must be a numeric'
  end

  def test_invalid_with_unrecognized_bank_files_country_code
    vendor = IntacctRest::Model::Vendor.new(id: 'V-00014', name: 'NCS, Inc.',
                                             bank_files: { 'paymentCountryCode' => 'zz' })

    refute vendor.valid?
    assert(vendor.errors.any? { |error| error.include?('bank_files_payment_country_code') })
  end

  def test_valid_with_recognized_bank_files_country_code
    vendor = IntacctRest::Model::Vendor.new(id: 'V-00014', name: 'NCS, Inc.',
                                             bank_files: { 'paymentCountryCode' => 'us' })

    assert vendor.valid?
  end

  def test_valid_with_bank_files_missing_country_code
    vendor = IntacctRest::Model::Vendor.new(id: 'V-00014', name: 'NCS, Inc.',
                                             bank_files: { 'paymentCurrency' => 'EUR' })

    assert vendor.valid?
  end

  def test_subclass_can_add_validations_without_losing_the_base_ones
    strict_vendor_class = Class.new(IntacctRest::Model::Vendor) do
      validate :presence, %i[tax_id]
    end

    vendor = strict_vendor_class.new(id: 'V-00014')

    refute vendor.valid?
    assert_includes vendor.errors, 'name is required'
    assert_includes vendor.errors, 'tax_id is required'
  end

  def test_subclass_can_add_a_custom_validator
    strict_vendor_class = Class.new(IntacctRest::Model::Vendor) do
      validate :custom, :valid_date, %i[last_payment_made_date]

      private

      def valid_date(date)
        date > default_date
      end

      def default_date
        Date.new(2026, 1, 1)
      end
    end

    invalid = strict_vendor_class.new(id: 'V-00014', name: 'NCS, Inc.', last_payment_made_date: Date.new(2020, 1, 1))
    valid = strict_vendor_class.new(id: 'V-00014', name: 'NCS, Inc.', last_payment_made_date: Date.new(2027, 1, 1))

    refute invalid.valid?
    assert_includes invalid.errors, 'last_payment_made_date is invalid'
    assert valid.valid?
  end

  def test_new_from_an_arbitrary_source_object
    source = Source.new('V-00014', 'NCS, Inc.', 40_000, 'ignored')

    vendor = IntacctRest::Model::Vendor.new(source)

    assert_equal 'V-00014', vendor.id
    assert_equal 'NCS, Inc.', vendor.name
    assert_equal 40_000, vendor.credit_limit
  end

  def test_new_from_source_object_with_keyword_overrides
    source = Source.new('V-00014', 'NCS, Inc.', 40_000, nil)

    vendor = IntacctRest::Model::Vendor.new(source, credit_limit: 1_000)

    assert_equal 'V-00014', vendor.id
    assert_equal 1_000, vendor.credit_limit
  end

  def test_custom_fields_accepts_custom_field_instances
    field = IntacctRest::CustomField.new(name: 'preferredCourier', value: 'UPS')
    vendor = IntacctRest::Model::Vendor.new(id: 'V-00014', name: 'NCS, Inc.', custom_fields: [field])

    assert_equal 'preferredCourier', vendor.custom_fields.first.name
    assert_equal 'UPS', vendor.custom_fields.first.value
    assert_equal 'nsp', vendor.custom_fields.first.namespace
  end

  def test_custom_fields_accepts_a_flat_hash_for_backward_compatibility
    vendor = IntacctRest::Model::Vendor.new(id: 'V-00014', name: 'NCS, Inc.',
                                             custom_fields: { 'preferredCourier' => 'UPS' })

    assert_equal 'preferredCourier', vendor.custom_fields.first.name
    assert_equal 'UPS', vendor.custom_fields.first.value
  end

  def test_payload_merges_custom_fields_with_nsp_prefix
    vendor = IntacctRest::Model::Vendor.new(id: 'V-00014', name: 'NCS, Inc.',
                                             custom_fields: { 'preferredCourier' => 'UPS' })

    assert_equal(
      { 'id' => 'V-00014', 'name' => 'NCS, Inc.', 'nsp::preferredCourier' => 'UPS' },
      vendor.payload
    )
  end

  def test_apply_result_sets_key_href_and_backfills_id
    vendor = IntacctRest::Model::Vendor.new(name: 'NCS, Inc.')
    success = IntacctRest::Result::Success.new(
      model: vendor, code: '201',
      body: { 'ia::result' => { 'key' => '111', 'href' => '/x/111', 'id' => 'AUTO-1' } }
    )

    vendor.apply_result(success)

    assert_equal '111', vendor.key
    assert_equal '/x/111', vendor.href
    assert_equal 'AUTO-1', vendor.id
  end
end
