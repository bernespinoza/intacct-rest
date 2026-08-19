require 'test_helper'

class TestModelCurrency < Minitest::Test
  Source = Struct.new(:base_currency, :txn_currency)

  def test_writable_attributes_are_accessible
    currency = IntacctRest::Model::Currency.new(base_currency: 'USD', txn_currency: 'EUR')

    assert_equal 'USD', currency.base_currency
    assert_equal 'EUR', currency.txn_currency
  end

  def test_valid_by_default
    assert IntacctRest::Model::Currency.new.valid?
  end

  def test_invalid_with_wrong_kind_of_attribute
    currency = IntacctRest::Model::Currency.new(txn_currency: 123)

    refute currency.valid?
    assert_includes currency.errors, 'txn_currency must be a string'
  end

  def test_invalid_with_exchange_rate_not_a_hash
    currency = IntacctRest::Model::Currency.new(exchange_rate: 'not-a-hash')

    refute currency.valid?
    assert_includes currency.errors, 'exchange_rate must be a hash'
  end

  def test_payload_uses_camel_case_json_keys
    currency = IntacctRest::Model::Currency.new(
      txn_currency: 'USD',
      exchange_rate: { 'date' => '2022-12-06', 'typeId' => 'Intacct Daily Rate', 'rate' => 0.05112 }
    )

    assert_equal(
      { 'txnCurrency' => 'USD', 'exchangeRate' => { 'date' => '2022-12-06', 'typeId' => 'Intacct Daily Rate', 'rate' => 0.05112 } },
      currency.payload
    )
  end

  def test_new_from_an_arbitrary_source_object
    currency = IntacctRest::Model::Currency.new(Source.new('USD', 'EUR'))

    assert_equal 'USD', currency.base_currency
    assert_equal 'EUR', currency.txn_currency
  end
end
