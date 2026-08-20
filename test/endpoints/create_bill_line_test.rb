require 'test_helper'

class TestEndpointsCreateBillLine < Minitest::Test
  def setup
    IntacctRest.reset
    IntacctRestTestConfig.apply
    @line = IntacctRest::Model::BillLine.new(
      bill: { 'key' => '19876' }, txn_amount: '5', gl_account: { 'id' => '6000' }
    )
    @line_url = "#{IntacctRest.configuration.base_url}#{@line.intacct_object}"
  end

  def teardown
    super
    IntacctRest.reset
  end

  def test_raises_argument_error_when_bill_line_is_not_a_model_bill_line
    assert_raises(ArgumentError) { IntacctRest::Endpoints::CreateBillLine.call(bill_line: { key: '19876' }) }
  end

  def test_call_raises_validation_error_without_any_http_request
    error = assert_raises(IntacctRest::ValidationError) do
      IntacctRest::Endpoints::CreateBillLine.call(bill_line: IntacctRest::Model::BillLine.new(txn_amount: '5'))
    end
    assert_includes error.message, 'bill is required'
    assert_includes error.message, 'gl_account is required'
  end

  def test_call_returns_success_result_with_default_result_fields
    stub_token_request
    stub_request(:post, @line_url)
      .with(body: hash_including('bill' => { 'key' => '19876' }, 'txnAmount' => '5', 'glAccount' => { 'id' => '6000' }))
      .to_return(
        status: 201,
        body: { 'ia::result' => { 'key' => '1955', 'id' => '1955', 'href' => '/objects/accounts-payable/bill-line/1955' } }.to_json
      )

    result = IntacctRest::Endpoints::CreateBillLine.call(bill_line: @line)

    assert result.success?
    assert_same @line, result.model
    assert_equal '1955', @line.key
  end

  def test_raises_api_error_when_an_expected_result_field_is_missing
    stub_token_request
    stub_request(:post, @line_url)
      .to_return(status: 201, body: { 'ia::result' => { 'key' => '1955' } }.to_json) # no href

    error = assert_raises(IntacctRest::ApiError) do
      IntacctRest::Endpoints::CreateBillLine.call(bill_line: @line, results: %i[id key href])
    end

    assert_includes error.message, 'href'
  end

  def test_failed_result_skips_result_field_verification
    stub_token_request
    stub_request(:post, @line_url)
      .to_return(status: 400, body: { 'ia::result' => { 'ia::error' => { 'message' => 'bad' } } }.to_json)

    result = IntacctRest::Endpoints::CreateBillLine.call(bill_line: @line)

    assert result.failed?
  end

  private

  def stub_token_request
    token_url = "#{IntacctRest.configuration.base_url}#{IntacctRest.configuration.token_path}"
    stub_request(:post, token_url)
      .to_return(status: 200, body: { access_token: 'tok-1', expires_in: 3600 }.to_json)
  end
end
