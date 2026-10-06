# frozen_string_literal: true

module IntacctRest
  module Endpoints
    # Delete /objects/accounts-payable/delete/{key}. delete.key picks the
    # record; only the key field is required and sent.

    class DeleteInvoice
      # model already knows the invoice data it just checks http response.
      def self.call(invoice:, results: [], config: IntacctRest.configuration, token_provider: nil)
        unless invoice.is_a?(IntacctRest::Model::Invoice)
          raise ArgumentError, 'invoice must be an IntacctRest::Model::Invoice'
        end

        result = IntacctRest::Delete.call(invoice, config: config, token_provider: token_provider)

        result
      end
    end
  end
end
