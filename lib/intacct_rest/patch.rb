# frozen_string_literal: true

module IntacctRest
  # Generic operation for PATCH-ing (updating) any model that responds to
  # #intacct_object (the collection path), #key (the record appended to
  # it), #update_payload (the outgoing JSON hash — only the fields to
  # change), and #valid?/#errors with an :update context. Raises
  # IntacctRest::ValidationError if the model is invalid for update,
  # before sending anything. Otherwise always returns an
  # IntacctRest::Result (Success or Error) — never raises for the HTTP
  # outcome itself. On success, calls model.apply_result(result) so the
  # model can absorb whatever it cares about from the response.
  class Patch
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
      errors = model.errors(:update)
      raise IntacctRest::ValidationError.new(errors.join('; '), attributes: errors) unless errors.empty?

      path = "#{model.intacct_object}/#{model.key}"
      response = authenticated_response(:patch, path, body: model.update_payload)
      parsed = parse_json(response.body, path)
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
