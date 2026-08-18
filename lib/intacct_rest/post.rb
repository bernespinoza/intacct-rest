# frozen_string_literal: true

module IntacctRest
  # Generic operation for POST-ing any model that responds to
  # #intacct_object (the endpoint path), #payload (the outgoing JSON
  # hash), and #valid?/#errors. Raises IntacctRest::ValidationError if the
  # model is invalid, before sending anything. Otherwise always returns an
  # IntacctRest::Result (Success or Error) — never raises for the HTTP
  # outcome itself. On success, calls model.apply_result(result) so the
  # model can absorb whatever it cares about from the response.
  class Post
    include AuthenticatedRequest

    def self.call(model, config: IntacctRest.configuration, token_provider: nil)
      new(config: config, token_provider: token_provider).send(:perform, model)
    end

    def initialize(config: IntacctRest.configuration, token_provider: nil)
      @config = config
      @token_provider = token_provider || IntacctRest::OauthClient.new(config: config)
    end

    private

    attr_reader :config, :token_provider

    def perform(model)
      raise IntacctRest::ValidationError.new(model.errors.join('; '), attributes: model.errors) unless model.valid?

      response = authenticated_response(:post, model.intacct_object, body: model.payload)
      parsed = parse_json(response.body, model.intacct_object)
      result = build_result(model, response, parsed)
      model.apply_result(result) if result.success?
      result
    end

    def build_result(model, response, parsed)
      klass = response.is_a?(Net::HTTPSuccess) ? IntacctRest::Result::Success : IntacctRest::Result::Error
      klass.new(model: model, code: response.code, body: parsed, headers: response.to_hash)
    end
  end
end
