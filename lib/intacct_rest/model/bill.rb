# frozen_string_literal: true

module IntacctRest
  module Model
    # An AP bill's data and validations only — no config, no token
    # provider, no HTTP. Build and inspect one freely; IntacctRest::Post
    # (via IntacctRest::Endpoints::CreateBill) is what actually sends it.
    #
    # Nested objects (vendor, term, currency, lines, ...) are NOT
    # individually modeled — pass them as raw Hashes using Intacct's
    # native (camelCase) nested key names, e.g.:
    #
    #   vendor: { "id" => "1099 Int" }
    #   lines: [{ "txnAmount" => "5", "glAccount" => { "id" => "6000" } }]
    #
    # Nested required fields (vendor.id, currency.txnCurrency,
    # lines[].txnAmount/glAccount, lines[].dimensions.location, ...) are
    # not validated client-side — only top-level presence/type is.
    # Intacct's own 400 response is the source of truth for those, same
    # boundary already accepted for Invoice/Customer/Vendor's nested
    # objects.
    class Bill < IntacctRest::Model::Base
      INTACCT_OBJECT = '/objects/accounts-payable/bill'.freeze

      WRITABLE_ATTRIBUTES = IntacctRest::Configuration::DEFAULT_BILL_WRITABLE_ATTRIBUTES

      # Set by IntacctRest::Post after a successful create — writable here
      # even though Intacct itself treats them as read-only.
      READONLY_ATTRIBUTES = %i[
        key id href module_name record_type due_in_days total_base_amount total_base_amount_due
        total_txn_amount total_txn_amount_due is_system_generated purchasing_document
        recurring_schedule e_invoice_status import_status import_error_message recipient_email
        sender_email anomaly_code document_source source_module payment_information retainage
        customer_refund entity web_url audit
      ].freeze

      attr_accessor(*WRITABLE_ATTRIBUTES.keys)
      attr_accessor(*READONLY_ATTRIBUTES)
      attr_reader :custom_fields

      validate :presence, %i[due_date created_date]

      validate :kind_of, :string, %i[
        bill_number state reference_number description posting_date discount_cut_off_date
        due_date recommended_payment_date created_date invoice_type invoice_mode
      ]
      validate :kind_of, :boolean, %i[is_on_hold is_tax_inclusive]
      validate :kind_of, :hash, %i[
        vendor term contacts currency tax_solution bill_summary bill_back_template attachment
        dispute refuse
      ]
      validate :kind_of, :array, %i[lines]

      # source: an arbitrary domain object (ActiveRecord record, OpenStruct,
      # another Model::Bill, ...) to pull matching attributes off of via
      # duck-typing — any WRITABLE_ATTRIBUTES/READONLY_ATTRIBUTES key it
      # responds to is copied over. Explicit keyword attributes always win
      # over whatever the source provided.
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

      # Ruby-side attributes (unmapped, no custom fields) — useful for
      # logging/introspection without the camelCase JSON translation.
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
