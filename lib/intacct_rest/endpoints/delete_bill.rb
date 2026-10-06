# frozen_string_literal: true

module IntacctRest
  module Endpoints
    # Delete /objects/accounts-payable/delete/{key}. delete.key picks the
    # record; only the key field is required and sent.

    class DeleteBill
      # model already knows the bill data it just checks http response.
      def self.call(bill:, results: [], config: IntacctRest.configuration, token_provider: nil)
        unless bill.is_a?(IntacctRest::Model::Bill)
          raise ArgumentError, 'bill must be an IntacctRest::Model::Bill'
        end

        result = IntacctRest::Delete.call(bill, config: config, token_provider: token_provider)

        result
      end
    end
  end
end
