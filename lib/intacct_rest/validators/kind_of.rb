# frozen_string_literal: true

module IntacctRest
  module Validators
    module KindOf
      TYPE_MAP = {
        string: String, integer: Integer, numeric: Numeric, float: Float,
        boolean: [TrueClass, FalseClass], hash: Hash, array: Array, date: Date, time: Time
      }.freeze

      def self.call(record, attribute, kind)
        value = record.public_send(attribute)
        return [] if value.nil?

        expected = TYPE_MAP.fetch(kind) { raise ArgumentError, "Unknown kind_of type: #{kind.inspect}" }
        return [] if Array(expected).any? { |klass| value.is_a?(klass) }

        ["#{attribute} must be a #{kind}"]
      end
    end

    register(:kind_of, KindOf)
  end
end
