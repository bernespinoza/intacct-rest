# frozen_string_literal: true

module IntacctRest
  module Endpoints
    class CreateTerm
      DEFAULT_RESULT_FIELDS = %i[id key href].freeze

      def self.call(term:, results: DEFAULT_RESULT_FIELDS, config: IntacctRest.configuration, token_provider: nil)
        raise ArgumentError, 'term must be an IntacctRest::Model::Term' unless term.is_a?(IntacctRest::Model::Term)

        result = IntacctRest::Post.call(term, config: config, token_provider: token_provider)
        verify_expected_fields!(result, results) if result.success?
        result
      end

      def self.verify_expected_fields!(result, expected_fields)
        missing = expected_fields.reject { |field| result.respond_to?(field) }
        return if missing.empty?

        raise IntacctRest::ApiError.new(
          "Expected result fields missing from response: #{missing.join(', ')}",
          http_status: result.code, body: result.body
        )
      end
      private_class_method :verify_expected_fields!
    end
  end
end
