require 'test_helper'

class TestModelBill < Minitest::Test
  Source = Struct.new(:bill_number, :due_date, :created_date)

  def test_writable_attributes_are_accessible
    bill = IntacctRest::Model::Bill.new(due_date: '2024-03-08', created_date: '2024-02-21',
                                         bill_number: 'Bill-001-06')

    assert_equal '2024-03-08', bill.due_date
    assert_equal '2024-02-21', bill.created_date
    assert_equal 'Bill-001-06', bill.bill_number
  end

  def test_custom_fields_defaults_to_empty_array
    bill = IntacctRest::Model::Bill.new(due_date: '2024-03-08', created_date: '2024-02-21')
    assert_equal([], bill.custom_fields)
  end

  def test_readonly_attributes_are_writable_for_the_operation_to_populate
    bill = IntacctRest::Model::Bill.new(due_date: '2024-03-08', created_date: '2024-02-21')
    bill.key = '299'
    bill.href = '/objects/accounts-payable/bill/299'

    assert_equal '299', bill.key
    assert_equal '/objects/accounts-payable/bill/299', bill.href
  end

  def test_intacct_object
    assert_equal '/objects/accounts-payable/bill', IntacctRest::Model::Bill.new.intacct_object
  end

  def test_valid_with_due_date_and_created_date
    assert IntacctRest::Model::Bill.new(due_date: '2024-03-08', created_date: '2024-02-21').valid?
  end

  def test_invalid_without_due_date
    bill = IntacctRest::Model::Bill.new(created_date: '2024-02-21')

    refute bill.valid?
    assert_includes bill.errors, 'due_date is required'
  end

  def test_invalid_without_created_date
    bill = IntacctRest::Model::Bill.new(due_date: '2024-03-08')

    refute bill.valid?
    assert_includes bill.errors, 'created_date is required'
  end

  def test_invalid_with_wrong_kind_of_attribute
    bill = IntacctRest::Model::Bill.new(due_date: '2024-03-08', created_date: '2024-02-21', vendor: 'not-a-hash')

    refute bill.valid?
    assert_includes bill.errors, 'vendor must be a hash'
  end

  def test_invalid_with_lines_not_an_array
    bill = IntacctRest::Model::Bill.new(due_date: '2024-03-08', created_date: '2024-02-21', lines: 'not-an-array')

    refute bill.valid?
    assert_includes bill.errors, 'lines must be a array'
  end

  def test_payload_uses_camel_case_json_keys_and_passes_vendor_reference_through
    bill = IntacctRest::Model::Bill.new(
      due_date: '2024-03-08', created_date: '2024-02-21',
      vendor: { 'id' => '1099 Int' },
      currency: { 'baseCurrency' => 'USD', 'txnCurrency' => 'USD' },
      lines: [{ 'txnAmount' => '5', 'glAccount' => { 'id' => '6000' } }]
    )

    assert_equal(
      {
        'dueDate' => '2024-03-08', 'createdDate' => '2024-02-21',
        'vendor' => { 'id' => '1099 Int' },
        'currency' => { 'baseCurrency' => 'USD', 'txnCurrency' => 'USD' },
        'lines' => [{ 'txnAmount' => '5', 'glAccount' => { 'id' => '6000' } }]
      },
      bill.payload
    )
  end

  def test_new_from_an_arbitrary_source_object
    source = Source.new('Bill-001-06', '2024-03-08', '2024-02-21')

    bill = IntacctRest::Model::Bill.new(source)

    assert_equal 'Bill-001-06', bill.bill_number
    assert_equal '2024-03-08', bill.due_date
    assert_equal '2024-02-21', bill.created_date
  end

  def test_apply_result_sets_key_href_and_backfills_id
    bill = IntacctRest::Model::Bill.new(due_date: '2024-03-08', created_date: '2024-02-21')
    success = IntacctRest::Result::Success.new(
      model: bill, code: '201',
      body: { 'ia::result' => { 'key' => '299', 'href' => '/objects/accounts-payable/bill/299', 'id' => '299' } }
    )

    bill.apply_result(success)

    assert_equal '299', bill.key
    assert_equal '/objects/accounts-payable/bill/299', bill.href
    assert_equal '299', bill.id
  end

  def test_subclass_can_add_validations_without_losing_the_base_ones
    strict_bill_class = Class.new(IntacctRest::Model::Bill) do
      validate :presence, %i[bill_number]
    end

    bill = strict_bill_class.new(due_date: '2024-03-08')

    refute bill.valid?
    assert_includes bill.errors, 'created_date is required'
    assert_includes bill.errors, 'bill_number is required'
  end
end
