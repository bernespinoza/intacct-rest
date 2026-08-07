# frozen_string_literal: true

module IntacctRest
  class Client
    HTTP_POST = 'Post'.freeze
    HTTP_GET  = 'Get'.freeze
    HTTP_PUT  = 'Put'.freeze
    HTTP_DELETE = 'Delete'.freeze
    METHODS = {
      post:   HTTP_POST,
      get:    HTTP_GET,
      put:    HTTP_PUT,
      delete: HTTP_DELETE
    }
    attr_reader :uri, :http, :net_request

    def initialize(uri, method = METHODS.fetch(:post))
      @method = METHODS.fetch(method.to_sym, HTTP_POST)
      @uri = URI(uri)
      @http = Net::HTTP.new(@uri.host, @uri.port)
      @http.use_ssl = @uri.scheme == 'https'
      @net_request = Object.const_get("Net::HTTP::#{@method}").new(@uri)
      @body = {}
      @headers = default_headers
    end

    def body
      @body
    end

    def body=(value = {})
      @body.merge!(value)
    end

    def add_header(name, value)
      @headers[name] = value
    end

    def headers
      @headers
    end

    def request
      net_request.body = body.to_json
      headers.each_pair do |header, value|
        net_request.add_field(header,value)
      end
      http.request(net_request)
    end

    def request_method
      @method
    end

    private

    def default_headers
      {
        'CONTENT-TYPE' => 'application/json'
      }
    end
  end
end
