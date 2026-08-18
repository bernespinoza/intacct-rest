# frozen_string_literal: true

module IntacctRest
  module Endpoints
    class CreateVendor
      DEFAULT_RESULT_FIELDS = %i[id key href].freeze

      # results: fields this endpoint expects a successful response to
      # contain — checked after the fact (raises ApiError if Intacct's
      # response is missing one), not a filter on what gets written back.
      # model.apply_result already decides what it absorbs from any
      # successful result.
      def self.call(vendor:, results: DEFAULT_RESULT_FIELDS, config: IntacctRest.configuration, token_provider: nil)
        unless vendor.is_a?(IntacctRest::Model::Vendor)
          raise ArgumentError, 'vendor must be an IntacctRest::Model::Vendor'
        end

        result = IntacctRest::Post.call(vendor, config: config, token_provider: token_provider)
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
