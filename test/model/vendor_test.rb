require 'test_helper'

class TestModelVendor < Minitest::Test
  def test_writable_attributes_are_accessible
    vendor = IntacctRest::Model::Vendor.new(id: 'V-00014', name: 'NCS, Inc.', credit_limit: 40_000)

    assert_equal 'V-00014', vendor.id
    assert_equal 'NCS, Inc.', vendor.name
    assert_equal 40_000, vendor.credit_limit
  end

  def test_custom_fields_defaults_to_empty_hash
    assert_equal({}, IntacctRest::Model::Vendor.new(id: 'V-00014', name: 'NCS, Inc.').custom_fields)
  end

  def test_readonly_attributes_are_writable_for_the_operation_to_populate
    vendor = IntacctRest::Model::Vendor.new(id: 'V-00014', name: 'NCS, Inc.')
    vendor.key = '111'
    vendor.href = '/objects/accounts-payable/vendor/111'

    assert_equal '111', vendor.key
    assert_equal '/objects/accounts-payable/vendor/111', vendor.href
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
end
