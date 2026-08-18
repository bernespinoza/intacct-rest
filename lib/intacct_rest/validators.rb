# frozen_string_literal: true

module IntacctRest
  # Registry of validator modules, keyed by kind (:presence, :kind_of,
  # :inclusion, ...). Knows nothing about which validators exist itself —
  # each validators/*.rb file registers its own kind when required, so
  # adding a new validator kind never means editing this file.
  module Validators
    class << self
      def register(kind, validator)
        registry[kind] = validator
      end

      def fetch(kind)
        registry.fetch(kind) do
          known = []
          each_validator { |name, _| known << name }
          raise ArgumentError, "Unknown validator: #{kind.inspect} (known: #{known.join(', ')})"
        end
      end

      def each_validator(&block)
        registry.each(&block)
      end

      private

      def registry
        @registry ||= {}
      end
    end
  end
end
