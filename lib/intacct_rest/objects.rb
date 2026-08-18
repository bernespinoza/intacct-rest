# frozen_string_literal: true

module IntacctRest
  # Wraps Intacct's Objects API (GET /objects/{resource} and
  # GET /objects/{resource}/{key}) — distinct from the Query API (Query).
  # No pagination handling: callers needing more than "list" or "fetch one"
  # should use Query against the same resource instead.
  class Objects
    include AuthenticatedRequest

    attr_reader :token_provider

    def initialize(config: IntacctRest.configuration, token_provider: nil)
      @config = config
      @token_provider = token_provider || IntacctRest::OauthClient.new(config: config)
    end

    def list(resource)
      authenticated_request(:get, "/objects/#{resource}")['ia::result'] || []
    end

    def find(resource, key)
      authenticated_request(:get, "/objects/#{resource}/#{key}")['ia::result']
    end

    private

    attr_reader :config
  end
end
