# frozen_string_literal: true

module IntacctRest
  module Model
    # An AP bill line's data and validations only — no config, no token
    # provider, no HTTP. Build and inspect one freely; IntacctRest::Post
    # (via IntacctRest::Endpoints::CreateBillLine) is what actually sends
    # it.
    #
    # This is a standalone-creatable object (POST
    # /objects/accounts-payable/bill-line) distinct from the raw line-item
    # Hashes accepted by Model::Bill#lines — Intacct allows both: send
    # lines inline with the bill, or create them separately against an
    # existing bill via `bill: { "key" => "..." }`.
    #
    # Nested objects (glAccount, dimensions, allocation, ...) are NOT
    # individually modeled — pass them as raw Hashes using Intacct's
    # native (camelCase) nested key names.
    class BillLine < IntacctRest::Model::Base
      INTACCT_OBJECT = '/objects/accounts-payable/bill-line'.freeze

      WRITABLE_ATTRIBUTES = IntacctRest::Configuration::DEFAULT_BILL_LINE_WRITABLE_ATTRIBUTES

      # Set by IntacctRest::Post after a successful create — writable here
      # even though Intacct itself treats them as read-only.
      READONLY_ATTRIBUTES = %i[
        key id href line_number bill_amount base_amount currency payment_information
        is_sub_total base_location retainage created_date audit
      ].freeze

      attr_accessor(*WRITABLE_ATTRIBUTES.keys)
      attr_accessor(*READONLY_ATTRIBUTES)
      attr_reader :custom_fields

      validate :presence, %i[bill txn_amount gl_account]
      validate :kind_of, :string, %i[txn_amount total_txn_amount memo has_form1099]
      validate :kind_of, :boolean, %i[release_to_pay]
      validate :kind_of, :hash, %i[
        vendor gl_account override_offset_gl_account account_label allocation form1099 project
        fixed_asset amortization_template purchasing dimensions bill
      ]
      validate :kind_of, :array, %i[tax_entries]

      def initialize(source = nil, custom_fields: [], **attributes)
        self.custom_fields = custom_fields
        merged = source ? attributes_from(source).merge(attributes) : attributes
        merged.each { |key, value| public_send(:"#{key}=", value) if respond_to?(:"#{key}=") }
      end

      def custom_fields=(value)
        @custom_fields = normalize_custom_fields(value)
      end

      def intacct_object
        self.class::INTACCT_OBJECT
      end

      def attributes
        WRITABLE_ATTRIBUTES.keys.each_with_object({}) { |attr, hash| hash[attr] = public_send(attr) }
      end

      def payload
        WRITABLE_ATTRIBUTES.each_with_object({}) do |(attr, json_key), hash|
          value = public_send(attr)
          hash[json_key] = value unless value.nil?
        end.merge(custom_fields_payload)
      end

      # Called by IntacctRest::Post after a successful create.
      def apply_result(result)
        data = result.result
        self.key = data['key'] if data['key']
        self.href = data['href'] if data['href']
        self.id = data['id'] if data['id'] && id.nil?
      end

      private

      def attributes_from(source)
        (WRITABLE_ATTRIBUTES.keys + READONLY_ATTRIBUTES).each_with_object({}) do |attr, hash|
          hash[attr] = source.public_send(attr) if source.respond_to?(attr)
        end
      end

      def normalize_custom_fields(value)
        case value
        when Array
          value.map { |v| v.is_a?(IntacctRest::CustomField) ? v : IntacctRest::CustomField.new(**v) }
        when Hash
          value.map { |name, val| IntacctRest::CustomField.new(name: name.to_s, value: val) }
        when nil
          []
        else
          raise ArgumentError, "Unsupported custom_fields value: #{value.class}"
        end
      end

      def custom_fields_payload
        custom_fields.each_with_object({}) { |field, hash| hash[field.key] = field.value }
      end
    end
  end
end
