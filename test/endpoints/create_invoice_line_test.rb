require 'test_helper'

class TestEndpointsCreateInvoiceLine < Minitest::Test
  def setup
    IntacctRest.reset
    IntacctRestTestConfig.apply
    @line = IntacctRest::Model::InvoiceLine.new(
      invoice: { 'key' => '350' }, txn_amount: '70.00', gl_account: { 'id' => '4000' }
    )
    @line_url = "#{IntacctRest.configuration.base_url}#{@line.intacct_object}"
  end

  def teardown
    super
    IntacctRest.reset
  end

  def test_raises_argument_error_when_invoice_line_is_not_a_model_invoice_line
    assert_raises(ArgumentError) { IntacctRest::Endpoints::CreateInvoiceLine.call(invoice_line: { key: '350' }) }
  end

  def test_call_raises_validation_error_without_any_http_request
    error = assert_raises(IntacctRest::ValidationError) do
      IntacctRest::Endpoints::CreateInvoiceLine.call(invoice_line: IntacctRest::Model::InvoiceLine.new(txn_amount: '70.00'))
    end
    assert_includes error.message, 'invoice is required'
    assert_includes error.message, 'gl_account is required'
  end

  def test_call_returns_success_result_with_default_result_fields
    stub_token_request
    stub_request(:post, @line_url)
      .with(body: hash_including('invoice' => { 'key' => '350' }, 'txnAmount' => '70.00', 'glAccount' => { 'id' => '4000' }))
      .to_return(
        status: 201,
        body: { 'ia::result' => { 'key' => '806', 'id' => '806', 'href' => '/objects/accounts-receivable/invoice-line/806' } }.to_json
      )

    result = IntacctRest::Endpoints::CreateInvoiceLine.call(invoice_line: @line)

    assert result.success?
    assert_same @line, result.model
    assert_equal '806', @line.key
  end

  def test_raises_api_error_when_an_expected_result_field_is_missing
    stub_token_request
    stub_request(:post, @line_url)
      .to_return(status: 201, body: { 'ia::result' => { 'key' => '806' } }.to_json) # no href

    error = assert_raises(IntacctRest::ApiError) do
      IntacctRest::Endpoints::CreateInvoiceLine.call(invoice_line: @line, results: %i[id key href])
    end

    assert_includes error.message, 'href'
  end

  def test_failed_result_skips_result_field_verification
    stub_token_request
    stub_request(:post, @line_url)
      .to_return(status: 400, body: { 'ia::result' => { 'ia::error' => { 'message' => 'bad' } } }.to_json)

    result = IntacctRest::Endpoints::CreateInvoiceLine.call(invoice_line: @line)

    assert result.failed?
  end

  private

  def stub_token_request
    token_url = "#{IntacctRest.configuration.base_url}#{IntacctRest.configuration.token_path}"
    stub_request(:post, token_url)
      .to_return(status: 200, body: { access_token: 'tok-1', expires_in: 3600 }.to_json)
  end
end
