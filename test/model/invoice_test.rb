require 'test_helper'

class TestModelInvoice < Minitest::Test
  Source = Struct.new(:invoice_number, :invoice_date, :due_date)

  def test_writable_attributes_are_accessible
    invoice = IntacctRest::Model::Invoice.new(invoice_date: '2022-12-06', due_date: '2022-12-31',
                                               invoice_number: 'SI-0034')

    assert_equal '2022-12-06', invoice.invoice_date
    assert_equal '2022-12-31', invoice.due_date
    assert_equal 'SI-0034', invoice.invoice_number
  end

  def test_custom_fields_defaults_to_empty_array
    invoice = IntacctRest::Model::Invoice.new(invoice_date: '2022-12-06', due_date: '2022-12-31')
    assert_equal([], invoice.custom_fields)
  end

  def test_readonly_attributes_are_writable_for_the_operation_to_populate
    invoice = IntacctRest::Model::Invoice.new(invoice_date: '2022-12-06', due_date: '2022-12-31')
    invoice.key = '2091'
    invoice.href = '/objects/accounts-receivable/invoice/2091'

    assert_equal '2091', invoice.key
    assert_equal '/objects/accounts-receivable/invoice/2091', invoice.href
  end

  def test_intacct_object
    assert_equal '/objects/accounts-receivable/invoice', IntacctRest::Model::Invoice.new.intacct_object
  end

  def test_valid_with_invoice_date_and_due_date
    assert IntacctRest::Model::Invoice.new(invoice_date: '2022-12-06', due_date: '2022-12-31').valid?
  end

  def test_invalid_without_invoice_date
    invoice = IntacctRest::Model::Invoice.new(due_date: '2022-12-31')

    refute invoice.valid?
    assert_includes invoice.errors, 'invoice_date is required'
  end

  def test_invalid_without_due_date
    invoice = IntacctRest::Model::Invoice.new(invoice_date: '2022-12-06')

    refute invoice.valid?
    assert_includes invoice.errors, 'due_date is required'
  end

  def test_invalid_with_wrong_kind_of_attribute
    invoice = IntacctRest::Model::Invoice.new(invoice_date: '2022-12-06', due_date: '2022-12-31',
                                               customer: 'not-a-hash')

    refute invoice.valid?
    assert_includes invoice.errors, 'customer must be a hash'
  end

  def test_invalid_with_lines_not_an_array
    invoice = IntacctRest::Model::Invoice.new(invoice_date: '2022-12-06', due_date: '2022-12-31',
                                               lines: 'not-an-array')

    refute invoice.valid?
    assert_includes invoice.errors, 'lines must be a array'
  end

  def test_payload_uses_camel_case_json_keys_and_passes_customer_reference_through
    invoice = IntacctRest::Model::Invoice.new(
      invoice_date: '2022-12-06', due_date: '2022-12-31',
      customer: { 'id' => 'C-00019' },
      lines: [{ 'txnAmount' => '100.40', 'glAccount' => { 'id' => '5004' } }]
    )

    assert_equal(
      {
        'invoiceDate' => '2022-12-06', 'dueDate' => '2022-12-31',
        'customer' => { 'id' => 'C-00019' },
        'lines' => [{ 'txnAmount' => '100.40', 'glAccount' => { 'id' => '5004' } }]
      },
      invoice.payload
    )
  end

  def test_new_from_an_arbitrary_source_object
    source = Source.new('SI-0034', '2022-12-06', '2022-12-31')

    invoice = IntacctRest::Model::Invoice.new(source)

    assert_equal 'SI-0034', invoice.invoice_number
    assert_equal '2022-12-06', invoice.invoice_date
    assert_equal '2022-12-31', invoice.due_date
  end

  def test_apply_result_sets_key_href_and_backfills_id
    invoice = IntacctRest::Model::Invoice.new(invoice_date: '2022-12-06', due_date: '2022-12-31')
    success = IntacctRest::Result::Success.new(
      model: invoice, code: '201',
      body: { 'ia::result' => { 'key' => '2091', 'href' => '/objects/accounts-receivable/invoice/2091', 'id' => '2091' } }
    )

    invoice.apply_result(success)

    assert_equal '2091', invoice.key
    assert_equal '/objects/accounts-receivable/invoice/2091', invoice.href
    assert_equal '2091', invoice.id
  end

  def test_subclass_can_add_validations_without_losing_the_base_ones
    strict_invoice_class = Class.new(IntacctRest::Model::Invoice) do
      validate :presence, %i[invoice_number]
    end

    invoice = strict_invoice_class.new(due_date: '2022-12-31')

    refute invoice.valid?
    assert_includes invoice.errors, 'invoice_date is required'
    assert_includes invoice.errors, 'invoice_number is required'
  end
end
