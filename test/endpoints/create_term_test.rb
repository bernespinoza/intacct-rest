require 'test_helper'

class TestEndpointsCreateTerm < Minitest::Test
  def setup
    IntacctRest.reset
    IntacctRestTestConfig.apply
    @term = IntacctRest::Model::Term.new(id: '2-10 Net 30', description: 'N30 with discount')
    @term_url = "#{IntacctRest.configuration.base_url}#{@term.intacct_object}"
  end

  def teardown
    super
    IntacctRest.reset
  end

  def test_raises_argument_error_when_term_is_not_a_model_term
    assert_raises(ArgumentError) { IntacctRest::Endpoints::CreateTerm.call(term: { id: '2-10 Net 30' }) }
  end

  def test_call_raises_validation_error_without_any_http_request
    error = assert_raises(IntacctRest::ValidationError) do
      IntacctRest::Endpoints::CreateTerm.call(term: IntacctRest::Model::Term.new(id: '2-10 Net 30'))
    end
    assert_includes error.message, 'description is required'
  end

  def test_call_returns_success_result_with_default_result_fields
    stub_token_request
    stub_request(:post, @term_url)
      .with(body: hash_including('id' => '2-10 Net 30', 'description' => 'N30 with discount'))
      .to_return(
        status: 201,
        body: { 'ia::result' => { 'key' => '18', 'id' => '2-10 Net 30', 'href' => '/objects/accounts-receivable/term/18' } }.to_json
      )

    result = IntacctRest::Endpoints::CreateTerm.call(term: @term)

    assert result.success?
    assert_same @term, result.model
    assert_equal '18', @term.key
  end

  def test_raises_api_error_when_an_expected_result_field_is_missing
    stub_token_request
    stub_request(:post, @term_url)
      .to_return(status: 201, body: { 'ia::result' => { 'key' => '18' } }.to_json) # no href

    error = assert_raises(IntacctRest::ApiError) do
      IntacctRest::Endpoints::CreateTerm.call(term: @term, results: %i[id key href])
    end

    assert_includes error.message, 'href'
  end

  def test_failed_result_skips_result_field_verification
    stub_token_request
    stub_request(:post, @term_url)
      .to_return(status: 400, body: { 'ia::result' => { 'ia::error' => { 'message' => 'bad' } } }.to_json)

    result = IntacctRest::Endpoints::CreateTerm.call(term: @term)

    assert result.failed?
  end

  private

  def stub_token_request
    token_url = "#{IntacctRest.configuration.base_url}#{IntacctRest.configuration.token_path}"
    stub_request(:post, token_url)
      .to_return(status: 200, body: { access_token: 'tok-1', expires_in: 3600 }.to_json)
  end
end
