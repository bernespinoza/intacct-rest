require 'test_helper'

class TestEndpointsCreateCustomer < Minitest::Test
  def setup
    IntacctRest.reset
    IntacctRestTestConfig.apply
    @customer = IntacctRest::Model::Customer.new(id: 'CUST-002', name: 'Starluck')
    @customer_url = "#{IntacctRest.configuration.base_url}#{@customer.intacct_object}"
  end

  def teardown
    super
    IntacctRest.reset
  end

  def test_raises_argument_error_when_customer_is_not_a_model_customer
    assert_raises(ArgumentError) { IntacctRest::Endpoints::CreateCustomer.call(customer: { name: 'Starluck' }) }
  end

  def test_call_raises_validation_error_without_any_http_request
    error = assert_raises(IntacctRest::ValidationError) do
      IntacctRest::Endpoints::CreateCustomer.call(customer: IntacctRest::Model::Customer.new)
    end
    assert_includes error.message, 'name is required'
  end

  def test_call_returns_success_result_with_default_result_fields
    stub_token_request
    stub_request(:post, @customer_url)
      .with(body: hash_including('id' => 'CUST-002', 'name' => 'Starluck'))
      .to_return(
        status: 201,
        body: { 'ia::result' => { 'key' => '32', 'id' => 'CUST-200', 'href' => '/objects/accounts-receivable/customer/32' } }.to_json
      )

    result = IntacctRest::Endpoints::CreateCustomer.call(customer: @customer)

    assert result.success?
    assert_same @customer, result.model
    assert_equal '32', @customer.key
  end

  def test_raises_api_error_when_an_expected_result_field_is_missing
    stub_token_request
    stub_request(:post, @customer_url)
      .to_return(status: 201, body: { 'ia::result' => { 'key' => '32' } }.to_json) # no href

    error = assert_raises(IntacctRest::ApiError) do
      IntacctRest::Endpoints::CreateCustomer.call(customer: @customer, results: %i[id key href])
    end

    assert_includes error.message, 'href'
  end

  def test_failed_result_skips_result_field_verification
    stub_token_request
    stub_request(:post, @customer_url)
      .to_return(status: 400, body: { 'ia::result' => { 'ia::error' => { 'message' => 'bad' } } }.to_json)

    result = IntacctRest::Endpoints::CreateCustomer.call(customer: @customer)

    assert result.failed?
  end

  private

  def stub_token_request
    token_url = "#{IntacctRest.configuration.base_url}#{IntacctRest.configuration.token_path}"
    stub_request(:post, token_url)
      .to_return(status: 200, body: { access_token: 'tok-1', expires_in: 3600 }.to_json)
  end
end
