# frozen_string_literal: true

module IntacctRest
  module Model
    # A contact's data and validations only — no config, no token
    # provider, no HTTP, and no create endpoint of its own (Intacct has no
    # standalone "create a contact" endpoint documented; contacts are
    # referenced by id from vendor/customer's `contacts`/`contact_list`
    # fields, which stay raw Hashes there). This is a small typed helper
    # for building that nested payload with validation.
    class Contact < IntacctRest::Model::Base
      ATTRIBUTES = IntacctRest::Configuration::DEFAULT_CONTACT_ATTRIBUTES

      attr_accessor(*ATTRIBUTES.keys)

      validate :presence, %i[id]
      validate :kind_of, :string, %i[id international_tax_id]
      validate :kind_of, :boolean, %i[show_in_contact_list]
      validate :kind_of, :hash, %i[tax electronic_invoice_details electronic_address]

      # source: an arbitrary domain object (ActiveRecord record, OpenStruct,
      # another Model::Contact, ...) to pull matching attributes off of via
      # duck-typing. Explicit keyword attributes always win over whatever
      # the source provided.
      def initialize(source = nil, **attributes)
        merged = source ? attributes_from(source).merge(attributes) : attributes
        merged.each { |key, value| public_send(:"#{key}=", value) if respond_to?(:"#{key}=") }
      end

      # Ruby-side attributes (unmapped) — useful for logging/introspection
      # without the camelCase JSON translation.
      def attributes
        ATTRIBUTES.keys.each_with_object({}) { |attr, hash| hash[attr] = public_send(attr) }
      end

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
