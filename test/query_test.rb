require 'test_helper'

class TestQuery < Minitest::Test
  def setup
    IntacctRest.reset
    IntacctRestTestConfig.apply
    @resource = 'accounts-receivable/invoice'
    @schema   = %w[key state]
    @query_url = "#{IntacctRest.configuration.base_url}#{IntacctRest.configuration.query_path}"
  end

  def teardown
    super
    IntacctRest.reset
  end

  def test_resource
    query = IntacctRest::Query.new(resource: @resource)
    assert_equal @resource, query.resource
  end

  def test_schema
    query = IntacctRest::Query.new(resource: @resource, schema: @schema)
    assert_equal @schema, query.schema
  end

  def test_url
    query = IntacctRest::Query.new(resource: @resource, schema: @schema)
    assert_equal @query_url, query.url
  end

  def test_token_provider_defaults_to_an_oauth_client
    query = IntacctRest::Query.new(resource: @resource, schema: @schema)
    assert_instance_of IntacctRest::OauthClient, query.token_provider
  end

  def test_payload
    query = IntacctRest::Query.new(resource: @resource, schema: @schema,
                                    filters: [IntacctRest::Filter.eq('state', 'paid')])
    assert_equal(
      { 'object' => @resource, 'fields' => @schema, 'filters' => [{ '$eq' => { 'state' => 'paid' } }], 'size' => 200 },
      query.payload
    )
  end

  def test_payload_omits_unset_optional_fields
    query = IntacctRest::Query.new(resource: @resource)
    assert_equal({ 'object' => @resource, 'fields' => [], 'filters' => [], 'size' => 200 }, query.payload)
  end

  def test_call_returns_a_page
    stub_token_request
    stub_request(:post, @query_url).to_return(
      status: 200,
      body: { 'ia::result' => [{ 'key' => '1' }], 'ia::meta' => { 'next' => '200' } }.to_json
    )

    page = IntacctRest::Query.new(resource: @resource, schema: @schema).call

    assert_equal [{ 'key' => '1' }], page.items
    assert_equal '200', page.next_cursor
  end

  def test_call_retries_once_after_401
    stub_token_request
    stub_request(:post, @query_url)
      .to_return(status: 401, body: 'unauthorized')
      .then
      .to_return(status: 200, body: { 'ia::result' => [], 'ia::meta' => {} }.to_json)

    page = IntacctRest::Query.new(resource: @resource, schema: @schema).call

    assert_equal [], page.items
  end

  def test_call_raises_api_error_on_repeated_401
    stub_token_request
    stub_request(:post, @query_url).to_return(status: 401, body: 'unauthorized')

    assert_raises(IntacctRest::AuthenticationError) do
      IntacctRest::Query.new(resource: @resource, schema: @schema).call
    end
  end

  def test_call_raises_api_error_on_http_failure
    stub_token_request
    stub_request(:post, @query_url).to_return(status: 500, body: 'boom')

    assert_raises(IntacctRest::ApiError) do
      IntacctRest::Query.new(resource: @resource, schema: @schema).call
    end
  end

  def test_call_raises_response_parse_error_on_invalid_json
    stub_token_request
    stub_request(:post, @query_url).to_return(status: 200, body: 'not json')

    assert_raises(IntacctRest::ResponseParseError) do
      IntacctRest::Query.new(resource: @resource, schema: @schema).call
    end
  end

  def test_each_page_yields_items_and_advances_cursor
    stub_token_request
    stub_request(:post, @query_url)
      .with { |req| !JSON.parse(req.body).key?('start') }
      .to_return(status: 200, body: { 'ia::result' => [{ 'key' => '1' }], 'ia::meta' => { 'next' => '200' } }.to_json)
    stub_request(:post, @query_url)
      .with(body: hash_including('start' => '200'))
      .to_return(status: 200, body: { 'ia::result' => [{ 'key' => '2' }], 'ia::meta' => {} }.to_json)

    pages = []
    IntacctRest::Query.new(resource: @resource, schema: @schema).each_page do |items, next_cursor|
      pages << [items, next_cursor]
    end

    assert_equal [[[{ 'key' => '1' }], '200'], [[{ 'key' => '2' }], nil]], pages
  end

  def test_each_page_raises_too_many_pages_error
    stub_token_request
    stub_request(:post, @query_url)
      .to_return(status: 200, body: { 'ia::result' => [], 'ia::meta' => { 'next' => 'more' } }.to_json)

    assert_raises(IntacctRest::TooManyPagesError) do
      IntacctRest::Query.new(resource: @resource, schema: @schema).each_page(max_pages: 2) { |*| }
    end
  end

  private

  def stub_token_request
    token_url = "#{IntacctRest.configuration.base_url}#{IntacctRest.configuration.token_path}"
    stub_request(:post, token_url)
      .to_return(status: 200, body: { access_token: 'tok-1', expires_in: 3600 }.to_json)
  end
end
