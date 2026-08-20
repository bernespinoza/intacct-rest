require 'test_helper'

class TestModelCustomer < Minitest::Test
  Source = Struct.new(:id, :name, :credit_limit)

  def test_writable_attributes_are_accessible
    customer = IntacctRest::Model::Customer.new(id: 'CUST-002', name: 'Starluck', credit_limit: 50_000)

    assert_equal 'CUST-002', customer.id
    assert_equal 'Starluck', customer.name
    assert_equal 50_000, customer.credit_limit
  end

  def test_custom_fields_defaults_to_empty_array
    assert_equal([], IntacctRest::Model::Customer.new(name: 'Starluck').custom_fields)
  end

  def test_readonly_attributes_are_writable_for_the_operation_to_populate
    customer = IntacctRest::Model::Customer.new(name: 'Starluck')
    customer.key = '32'
    customer.href = '/objects/accounts-receivable/customer/32'

    assert_equal '32', customer.key
    assert_equal '/objects/accounts-receivable/customer/32', customer.href
  end

  def test_intacct_object
    assert_equal '/objects/accounts-receivable/customer', IntacctRest::Model::Customer.new.intacct_object
  end

  def test_valid_with_name
    assert IntacctRest::Model::Customer.new(name: 'Starluck').valid?
  end

  def test_invalid_without_name
    customer = IntacctRest::Model::Customer.new

    refute customer.valid?
    assert_includes customer.errors, 'name is required'
  end

  def test_invalid_with_wrong_kind_of_attribute
    customer = IntacctRest::Model::Customer.new(name: 'Starluck', credit_limit: 'lots')

    refute customer.valid?
    assert_includes customer.errors, 'credit_limit must be a numeric'
  end

  def test_invalid_with_vendor_ref_not_a_hash
    customer = IntacctRest::Model::Customer.new(name: 'Starluck', vendor: 'not-a-hash')

    refute customer.valid?
    assert_includes customer.errors, 'vendor must be a hash'
  end

  def test_payload_uses_camel_case_json_keys_and_passes_vendor_reference_through
    customer = IntacctRest::Model::Customer.new(
      id: 'CUST-002', name: 'Starluck', vendor: { 'id' => 'V-00014' }
    )

    assert_equal(
      { 'id' => 'CUST-002', 'name' => 'Starluck', 'vendor' => { 'id' => 'V-00014' } },
      customer.payload
    )
  end

  def test_new_from_an_arbitrary_source_object
    source = Source.new('CUST-002', 'Starluck', 50_000)

    customer = IntacctRest::Model::Customer.new(source)

    assert_equal 'CUST-002', customer.id
    assert_equal 'Starluck', customer.name
    assert_equal 50_000, customer.credit_limit
  end

  def test_apply_result_sets_key_href_and_backfills_id
    customer = IntacctRest::Model::Customer.new(name: 'Starluck')
    success = IntacctRest::Result::Success.new(
      model: customer, code: '201',
      body: { 'ia::result' => { 'key' => '32', 'href' => '/objects/accounts-receivable/customer/32', 'id' => 'CUST-200' } }
    )

    customer.apply_result(success)

    assert_equal '32', customer.key
    assert_equal '/objects/accounts-receivable/customer/32', customer.href
    assert_equal 'CUST-200', customer.id
  end

  def test_subclass_can_add_validations_without_losing_the_base_ones
    strict_customer_class = Class.new(IntacctRest::Model::Customer) do
      validate :presence, %i[tax_id]
    end

    customer = strict_customer_class.new

    refute customer.valid?
    assert_includes customer.errors, 'name is required'
    assert_includes customer.errors, 'tax_id is required'
  end
end
