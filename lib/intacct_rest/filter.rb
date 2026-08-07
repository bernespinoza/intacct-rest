# frozen_string_literal: true

module IntacctRest
  # Builds Intacct's REST query filter fragments. Intacct expects `filters`
  # as an array of single-key hashes that are implicitly AND'd together.
  module Filter
    OPERATORS = {
      equalto:              '$eq',
      notequalto:           '$ne',
      greaterthan:          '$gt',
      greaterthanorequalto: '$gte',
      lessthan:             '$lt',
      lessthanorequalto:    '$lte'
    }.freeze

    class << self
      def eq(field, value)  = operator(:equalto, field, value)
      def not_eq(field, value) = operator(:notequalto, field, value)
      def gt(field, value)  = operator(:greaterthan, field, value)
      def gte(field, value) = operator(:greaterthanorequalto, field, value)
      def lt(field, value)  = operator(:lessthan, field, value)
      def lte(field, value) = operator(:lessthanorequalto, field, value)

      # Filters are implicitly AND'd by Intacct — this just documents intent at call sites.
      def and(*fragments) = fragments.flatten

      private

      def operator(name, field, value)
        { OPERATORS.fetch(name) => { field.to_s => value } }
      end
    end
  end
end
