# frozen_string_literal: true

module IntacctRest
  module Model
    # Currency details nested inside an invoice header or invoice line
    # (baseCurrency/txnCurrency/exchangeRate). Intacct has no standalone
    # "create a currency" endpoint anywhere in its REST API — this exists
    # purely as a small, validated way to build that nested Hash, e.g.:
    #
    #   currency = IntacctRest::Model::Currency.new(txn_currency: "EUR")
    #   invoice.currency = currency.payload
    #
    # exchangeRate stays a raw Hash — not individually modeled.
    class Currency < IntacctRest::Model::Base
      ATTRIBUTES = IntacctRest::Configuration::DEFAULT_CURRENCY_ATTRIBUTES

      attr_accessor(*ATTRIBUTES.keys)

      validate :kind_of, :string, %i[base_currency txn_currency]
      validate :kind_of, :hash, %i[exchange_rate]

      # source: an arbitrary domain object to pull matching attributes off
      # of via duck-typing. Explicit keyword attributes always win.
      def initialize(source = nil, **attributes)
        merged = source ? attributes_from(source).merge(attributes) : attributes
        merged.each { |key, value| public_send(:"#{key}=", value) if respond_to?(:"#{key}=") }
      end

      def attributes
        ATTRIBUTES.keys.each_with_object({}) { |attr, hash| hash[attr] = public_send(attr) }
      end

      # The camelCase Hash to embed into a parent's payload.
      def payload
        ATTRIBUTES.each_with_object({}) do |(attr, json_key), hash|
          value = public_send(attr)
          hash[json_key] = value unless value.nil?
        end
      end

      private

      def attributes_from(source)
        ATTRIBUTES.keys.each_with_object({}) do |attr, hash|
          hash[attr] = source.public_send(attr) if source.respond_to?(attr)
        end
      end
    end
  end
end
