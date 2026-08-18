# frozen_string_literal: true

module IntacctRest
  # Shared by any class that sends one authenticated HTTP request to the
  # Intacct REST API: retries once on 401 (refreshing the token first),
  # parses JSON, and raises on a non-2xx response or an `ia::error` payload.
  # Stops there — pagination (Query#each_page) and response shaping (Page)
  # are the including class's responsibility, not this module's.
  #
  # Including classes must expose private `config` and `token_provider`
  # readers (not enforced by Ruby — just the implicit contract here).
  module AuthenticatedRequest
    private

    def authenticated_request(method, path, body: nil)
      send_request(method, path, body, retried: false)
    end

    def send_request(method, path, body, retried:)
      client = IntacctRest::Client.new("#{config.base_url}#{path}", method)
      client.add_header('Authorization', "Bearer #{token_provider.access_token}")
      client.body = body if body

      response = client.request

      if response.is_a?(Net::HTTPUnauthorized)
        raise IntacctRest::AuthenticationError, 'Authentication failed after token refresh' if retried

        token_provider.refresh_access_token
        return send_request(method, path, body, retried: true)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise IntacctRest::ApiError.new("HTTP #{response.code} requesting #{path}",
                                         http_status: response.code, body: response.body)
      end

      parsed = parse_json(response.body, path)

      if parsed['ia::error']
        raise IntacctRest::ApiError.new("API error requesting #{path}", http_status: response.code, body: parsed)
      end

      parsed
    end

    def parse_json(body, path)
      JSON.parse(body)
    rescue JSON::ParserError => e
      raise IntacctRest::ResponseParseError.new("#{e.message} (#{path})", raw_body: body)
    end
  end
end
