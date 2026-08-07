# frozen_string_literal: true

module IntacctRest
  # OAuth2 token handling against Intacct's v1 token endpoint: client_credentials
  # and refresh_token grants, with pluggable token storage (see Configuration#token_store).
  class OauthClient
    TOKEN_EXPIRY_BUFFER = 60 # seconds

    def initialize(config: IntacctRest.configuration)
      @config = config
    end

    def access_token
      token_store.read(access_token_key) || fetch_token
    end

    def refresh_access_token
      refresh = token_store.read(refresh_token_key)
      refresh ? exchange_refresh_token(refresh) : fetch_token
    end

    private

    attr_reader :config

    def fetch_token
      store_tokens(post_token(grant_type: 'client_credentials'))
    end

    def exchange_refresh_token(refresh)
      store_tokens(post_token(grant_type: 'refresh_token', refresh_token: refresh))
    rescue IntacctRest::Error
      fetch_token
    end

    def post_token(params)
      client = IntacctRest::Client.new(token_url, :post)
      client.body = params.merge(
        client_id:     config.client_id,
        client_secret: config.client_secret,
        username:      config.username
      )

      response = client.request
      unless response.is_a?(Net::HTTPSuccess)
        raise IntacctRest::AuthenticationError,
              "OAuth token request failed: HTTP #{response.code} — #{response.body}"
      end

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise IntacctRest::ResponseParseError.new(e.message, raw_body: response&.body)
    end

    def store_tokens(parsed)
      ttl = [parsed['expires_in'].to_i - TOKEN_EXPIRY_BUFFER, 1].max
      token_store.write(access_token_key, parsed['access_token'], ttl: ttl)
      token_store.write(refresh_token_key, parsed['refresh_token']) if parsed['refresh_token']
      parsed['access_token']
    end

    def token_store
      config.token_store
    end

    def token_url
      "#{config.base_url}#{config.token_path}"
    end

    def access_token_key
      "#{config.token_key_prefix}:access_token"
    end

    def refresh_token_key
      "#{config.token_key_prefix}:refresh_token"
    end
  end
end
