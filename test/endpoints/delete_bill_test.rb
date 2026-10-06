require 'test_helper'

class TestEndpointsDeleteBill < Minitest::Test
  def setup
    IntacctRest.reset
    IntacctRestTestConfig.apply
    @bill = IntacctRest::Model::Bill.new(key: '111', id: 'B-00014', credit_limit: 10_000)
    @bill_url = "#{IntacctRest.configuration.base_url}#{@bill.intacct_object}/111"
  end

  def teardown
    super
    IntacctRest.reset
  end


  def test_raises_validation_error_without_key
    bill = IntacctRest::Model::Bill.new(credit_limit: 10_000)  # no key

    assert_raises(IntacctRest::ValidationError) { IntacctRest::Endpoints::DeleteBill.call(bill: bill) }
  end

  def test_call_returns_success_result_with_default_result_fields
    stub_token_request
    stub_request(:delete, @bill_url)
      .to_return(status: 200, body: ''.to_json)

    result = IntacctRest::Endpoints::DeleteBill.call(bill: @bill)

    assert result.success?
    assert_same @bill, result.model
    assert_equal 'B-00014', @bill.id
    assert_equal '111', @bill.key
  end

  private

  def stub_token_request
    token_url = "#{IntacctRest.configuration.base_url}#{IntacctRest.configuration.token_path}"
    stub_request(:post, token_url)
      .to_return(status: 200, body: { access_token: 'tok-1', expires_in: 3600 }.to_json)
  end
end
