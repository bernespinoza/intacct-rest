require 'test_helper'

class TestClient < Minitest::Test
  def setup
    @client = IntacctRest::Client
  end

  def test_uri
    uri = 'https://www.example.com'
    assert @client.new(uri)
  end

  def test_method
    uri = 'https://www.example.com'
    method = 'Post'
    assert @client.new(uri, method)
  end

  def test_request
    uri = 'https://www.example.com'
    stub_request(:post, uri).to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
    common_client = @client.new(uri)
    common_client.body = { test: 'value' }
    response = common_client.request
    assert_equal response.class, Net::HTTPOK
  end

  def test_body_default
    uri = 'https://www.example.com'
    body = {}
    assert_equal @client.new(uri).body, body
  end

  def test_body=
    params = {
      test: 'example'
    }
    uri = 'https://www.example.com'
    common_client = @client.new(uri)
    common_client.body = params
    assert_equal common_client.body, params
  end

  def test_default_headers
    default_headers = {
      'CONTENT-TYPE' => 'application/json'
    }
    uri = 'https://www.example.com'
    assert_equal @client.new(uri).headers, default_headers
  end

  def test_set_authetication_header
    headers = {
      'CONTENT-TYPE' => 'application/json',
      'AUTHENTICATION' => 'BEARER xxxxx'
    }
    uri = 'https://www.example.com'
    common_client = @client.new(uri)
    common_client.add_header('AUTHENTICATION', 'BEARER xxxxx')
    assert_equal common_client.headers, headers
  end

  def test_request_method
    uri = 'https://www.example.com'
    common_client = @client.new(uri, :get)
    assert_equal common_client.request_method, IntacctRest::Client::HTTP_GET
  end

  def test_request_method_invalid
    uri = 'https://www.example.com'
    common_client = @client.new(uri, :patch)
    assert_equal common_client.request_method, IntacctRest::Client::HTTP_POST
  end
end
