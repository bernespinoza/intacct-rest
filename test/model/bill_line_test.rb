require 'test_helper'

class TestModelBillLine < Minitest::Test
  def valid_attrs
    { bill: { 'key' => '19876' }, txn_amount: '5', gl_account: { 'id' => '6000' } }
  end

  def test_writable_attributes_are_accessible
    line = IntacctRest::Model::BillLine.new(**valid_attrs, memo: 'bill - 001 - vendor 1099')

    assert_equal({ 'key' => '19876' }, line.bill)
    assert_equal '5', line.txn_amount
    assert_equal({ 'id' => '6000' }, line.gl_account)
    assert_equal 'bill - 001 - vendor 1099', line.memo
  end

  def test_intacct_object
    assert_equal '/objects/accounts-payable/bill-line', IntacctRest::Model::BillLine.new.intacct_object
  end

  def test_valid_with_required_fields
    assert IntacctRest::Model::BillLine.new(**valid_attrs).valid?
  end

  def test_invalid_without_bill
    line = IntacctRest::Model::BillLine.new(txn_amount: '5', gl_account: { 'id' => '6000' })

    refute line.valid?
    assert_includes line.errors, 'bill is required'
  end

  def test_invalid_without_txn_amount
    line = IntacctRest::Model::BillLine.new(bill: { 'key' => '19876' }, gl_account: { 'id' => '6000' })

    refute line.valid?
    assert_includes line.errors, 'txn_amount is required'
  end

  def test_invalid_without_gl_account
    line = IntacctRest::Model::BillLine.new(bill: { 'key' => '19876' }, txn_amount: '5')

    refute line.valid?
    assert_includes line.errors, 'gl_account is required'
  end

  def test_invalid_with_dimensions_not_a_hash
    line = IntacctRest::Model::BillLine.new(**valid_attrs, dimensions: 'not-a-hash')

    refute line.valid?
    assert_includes line.errors, 'dimensions must be a hash'
  end

  def test_payload_uses_camel_case_json_keys
    line = IntacctRest::Model::BillLine.new(
      bill: { 'key' => '19876' }, txn_amount: '5', gl_account: { 'id' => '6000' },
      dimensions: { 'location' => { 'id' => '4' } }
    )

    assert_equal(
      {
        'bill' => { 'key' => '19876' }, 'txnAmount' => '5', 'glAccount' => { 'id' => '6000' },
        'dimensions' => { 'location' => { 'id' => '4' } }
      },
      line.payload
    )
  end

  def test_apply_result_sets_key_href_and_backfills_id
    line = IntacctRest::Model::BillLine.new(**valid_attrs)
    success = IntacctRest::Result::Success.new(
      model: line, code: '201',
      body: { 'ia::result' => { 'key' => '1955', 'href' => '/objects/accounts-payable/bill-line/1955', 'id' => '1955' } }
    )

    line.apply_result(success)

    assert_equal '1955', line.key
    assert_equal '/objects/accounts-payable/bill-line/1955', line.href
    assert_equal '1955', line.id
  end
end
