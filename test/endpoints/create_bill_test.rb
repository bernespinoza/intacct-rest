require 'test_helper'

class TestEndpointsCreateBill < Minitest::Test
  def setup
    IntacctRest.reset
    IntacctRestTestConfig.apply
    @bill = IntacctRest::Model::Bill.new(due_date: '2024-03-08', created_date: '2024-02-21',
                                          vendor: { 'id' => '1099 Int' })
    @bill_url = "#{IntacctRest.configuration.base_url}#{@bill.intacct_object}"
  end

  def teardown
    super
    IntacctRest.reset
  end

  def test_raises_argument_error_when_bill_is_not_a_model_bill
    assert_raises(ArgumentError) { IntacctRest::Endpoints::CreateBill.call(bill: { dueDate: '2024-03-08' }) }
  end

  def test_call_raises_validation_error_without_any_http_request
    error = assert_raises(IntacctRest::ValidationError) do
      IntacctRest::Endpoints::CreateBill.call(bill: IntacctRest::Model::Bill.new(due_date: '2024-03-08'))
    end
    assert_includes error.message, 'created_date is required'
  end

  def test_call_returns_success_result_with_default_result_fields
    stub_token_request
    stub_request(:post, @bill_url)
      .with(body: hash_including('dueDate' => '2024-03-08', 'createdDate' => '2024-02-21',
                                  'vendor' => { 'id' => '1099 Int' }))
      .to_return(
        status: 201,
        body: { 'ia::result' => { 'id' => '299', 'key' => '299', 'href' => '/objects/accounts-payable/bill/299' } }.to_json
      )

    result = IntacctRest::Endpoints::CreateBill.call(bill: @bill)

    assert result.success?
    assert_same @bill, result.model
    assert_equal '299', @bill.key
    assert_equal '/objects/accounts-payable/bill/299', @bill.href
  end

  def test_raises_api_error_when_an_expected_result_field_is_missing
    stub_token_request
    stub_request(:post, @bill_url)
      .to_return(status: 201, body: { 'ia::result' => { 'key' => '299' } }.to_json) # no href, no id

    error = assert_raises(IntacctRest::ApiError) do
      IntacctRest::Endpoints::CreateBill.call(bill: @bill, results: %i[id key href])
    end

    assert_includes error.message, 'href'
  end

  def test_failed_result_skips_result_field_verification
    stub_token_request
    stub_request(:post, @bill_url)
      .to_return(status: 400, body: { 'ia::result' => { 'ia::error' => { 'message' => 'bad' } } }.to_json)

    result = IntacctRest::Endpoints::CreateBill.call(bill: @bill)

    assert result.failed?
  end

  private

  def stub_token_request
    token_url = "#{IntacctRest.configuration.base_url}#{IntacctRest.configuration.token_path}"
    stub_request(:post, token_url)
      .to_return(status: 200, body: { access_token: 'tok-1', expires_in: 3600 }.to_json)
  end
end
