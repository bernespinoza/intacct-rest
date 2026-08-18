require 'test_helper'

class TestEndpointsCreateInvoice < Minitest::Test
  def setup
    IntacctRest.reset
    IntacctRestTestConfig.apply
    @invoice = IntacctRest::Model::Invoice.new(invoice_date: '2022-12-06', due_date: '2022-12-31',
                                                customer: { 'id' => 'C-00019' })
    @invoice_url = "#{IntacctRest.configuration.base_url}#{@invoice.intacct_object}"
  end

  def teardown
    super
    IntacctRest.reset
  end

  def test_raises_argument_error_when_invoice_is_not_a_model_invoice
    assert_raises(ArgumentError) { IntacctRest::Endpoints::CreateInvoice.call(invoice: { invoiceDate: '2022-12-06' }) }
  end

  def test_call_raises_validation_error_without_any_http_request
    error = assert_raises(IntacctRest::ValidationError) do
      IntacctRest::Endpoints::CreateInvoice.call(invoice: IntacctRest::Model::Invoice.new(due_date: '2022-12-31'))
    end
    assert_includes error.message, 'invoice_date is required'
  end

  def test_call_returns_success_result_with_default_result_fields
    stub_token_request
    stub_request(:post, @invoice_url)
      .with(body: hash_including('invoiceDate' => '2022-12-06', 'dueDate' => '2022-12-31',
                                  'customer' => { 'id' => 'C-00019' }))
      .to_return(
        status: 201,
        body: { 'ia::result' => { 'id' => '2091', 'key' => '2091', 'href' => '/objects/accounts-receivable/invoice/2091' } }.to_json
      )

    result = IntacctRest::Endpoints::CreateInvoice.call(invoice: @invoice)

    assert result.success?
    assert_same @invoice, result.model
    assert_equal '2091', @invoice.key
    assert_equal '/objects/accounts-receivable/invoice/2091', @invoice.href
  end

  def test_raises_api_error_when_an_expected_result_field_is_missing
    stub_token_request
    stub_request(:post, @invoice_url)
      .to_return(status: 201, body: { 'ia::result' => { 'key' => '2091' } }.to_json) # no href, no id

    error = assert_raises(IntacctRest::ApiError) do
      IntacctRest::Endpoints::CreateInvoice.call(invoice: @invoice, results: %i[id key href])
    end

    assert_includes error.message, 'href'
  end

  def test_failed_result_skips_result_field_verification
    stub_token_request
    stub_request(:post, @invoice_url)
      .to_return(status: 400, body: { 'ia::result' => { 'ia::error' => { 'message' => 'bad' } } }.to_json)

    result = IntacctRest::Endpoints::CreateInvoice.call(invoice: @invoice)

    assert result.failed?
  end

  private

  def stub_token_request
    token_url = "#{IntacctRest.configuration.base_url}#{IntacctRest.configuration.token_path}"
    stub_request(:post, token_url)
      .to_return(status: 200, body: { access_token: 'tok-1', expires_in: 3600 }.to_json)
  end
end
