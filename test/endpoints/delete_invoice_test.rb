require 'test_helper'

class TestEndpointsDeleteInvoice < Minitest::Test
  def setup
    IntacctRest.reset
    IntacctRestTestConfig.apply
    @invoice = IntacctRest::Model::Invoice.new(key: '111', id: 'I-00014', amount: 1000)
    @invoice_url = "#{IntacctRest.configuration.base_url}#{@invoice.intacct_object}/111"
  end

  def teardown
    super
    IntacctRest.reset
  end


  def test_raises_validation_error_without_key
    invoice = IntacctRest::Model::Invoice.new(amount: 1000)  # no key

    assert_raises(IntacctRest::ValidationError) { IntacctRest::Endpoints::DeleteInvoice.call(invoice: invoice) }
  end

  def test_call_returns_success_result_with_default_result_fields
    stub_token_request
    stub_request(:delete, @invoice_url)
      .to_return(status: 200, body: ''.to_json)

    result = IntacctRest::Endpoints::DeleteInvoice.call(invoice: @invoice)

    assert result.success?
    assert_same @invoice, result.model
    assert_equal 'I-00014', @invoice.id
    assert_equal '111', @invoice.key
  end

  private

  def stub_token_request
    token_url = "#{IntacctRest.configuration.base_url}#{IntacctRest.configuration.token_path}"
    stub_request(:post, token_url)
      .to_return(status: 200, body: { access_token: 'tok-1', expires_in: 3600 }.to_json)
  end
end