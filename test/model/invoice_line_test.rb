require 'test_helper'

class TestModelInvoiceLine < Minitest::Test
  def valid_attrs
    { invoice: { 'key' => '350' }, txn_amount: '70.00', gl_account: { 'id' => '4000' } }
  end

  def test_writable_attributes_are_accessible
    line = IntacctRest::Model::InvoiceLine.new(**valid_attrs, memo: 'Created memo')

    assert_equal({ 'key' => '350' }, line.invoice)
    assert_equal '70.00', line.txn_amount
    assert_equal({ 'id' => '4000' }, line.gl_account)
    assert_equal 'Created memo', line.memo
  end

  def test_intacct_object
    assert_equal '/objects/accounts-receivable/invoice-line', IntacctRest::Model::InvoiceLine.new.intacct_object
  end

  def test_valid_with_required_fields
    assert IntacctRest::Model::InvoiceLine.new(**valid_attrs).valid?
  end

  def test_invalid_without_invoice
    line = IntacctRest::Model::InvoiceLine.new(txn_amount: '70.00', gl_account: { 'id' => '4000' })

    refute line.valid?
    assert_includes line.errors, 'invoice is required'
  end

  def test_invalid_without_txn_amount
    line = IntacctRest::Model::InvoiceLine.new(invoice: { 'key' => '350' }, gl_account: { 'id' => '4000' })

    refute line.valid?
    assert_includes line.errors, 'txn_amount is required'
  end

  def test_invalid_without_gl_account
    line = IntacctRest::Model::InvoiceLine.new(invoice: { 'key' => '350' }, txn_amount: '70.00')

    refute line.valid?
    assert_includes line.errors, 'gl_account is required'
  end

  def test_invalid_with_dimensions_not_a_hash
    line = IntacctRest::Model::InvoiceLine.new(**valid_attrs, dimensions: 'not-a-hash')

    refute line.valid?
    assert_includes line.errors, 'dimensions must be a hash'
  end

  def test_payload_uses_camel_case_json_keys
    line = IntacctRest::Model::InvoiceLine.new(
      invoice: { 'key' => '350' }, txn_amount: '70.00', gl_account: { 'id' => '4000' },
      dimensions: { 'location' => { 'key' => '1' } }
    )

    assert_equal(
      {
        'invoice' => { 'key' => '350' }, 'txnAmount' => '70.00', 'glAccount' => { 'id' => '4000' },
        'dimensions' => { 'location' => { 'key' => '1' } }
      },
      line.payload
    )
  end

  def test_apply_result_sets_key_href_and_backfills_id
    line = IntacctRest::Model::InvoiceLine.new(**valid_attrs)
    success = IntacctRest::Result::Success.new(
      model: line, code: '201',
      body: { 'ia::result' => { 'key' => '806', 'href' => '/objects/accounts-receivable/invoice-line/806', 'id' => '806' } }
    )

    line.apply_result(success)

    assert_equal '806', line.key
    assert_equal '/objects/accounts-receivable/invoice-line/806', line.href
    assert_equal '806', line.id
  end
end
