# frozen_string_literal: true

module IntacctRest
  module Model
    # An AR invoice's data and validations only — no config, no token
    # provider, no HTTP. Build and inspect one freely; IntacctRest::Post
    # (via IntacctRest::Endpoints::CreateInvoice) is what actually sends it.
    #
    # Nested objects (customer, lines, currency, term, ...) are NOT
    # individually modeled — pass them as raw Hashes using Intacct's
    # native (camelCase) nested key names, e.g.:
    #
    #   customer: { "id" => "C-00019" }
    #   lines: [{ "txnAmount" => "100.40", "glAccount" => { "id" => "5004" } }]
    #
    # Nested required fields (customer.id, lines[].txnAmount, ...) are not
    # validated client-side — only top-level presence/type is. Intacct's
    # own 400 response is the source of truth for those, same boundary
    # already accepted for Vendor's nested objects.
    class Invoice < IntacctRest::Model::Base
      INTACCT_OBJECT = '/objects/accounts-receivable/invoice'.freeze

      WRITABLE_ATTRIBUTES = IntacctRest::Configuration::DEFAULT_INVOICE_WRITABLE_ATTRIBUTES

      # Set by IntacctRest::Post after a successful create — writable here
      # even though Intacct itself treats them as read-only, since this is
      # the only place that result gets recorded. `href` is appended even
      # though the invoice object schema omits it — the actual 201
      # response includes it, same as every other object here.
      READONLY_ATTRIBUTES = %i[
        key id record_type module_key due_in_days sales_document discount_cut_off_date
        total_base_amount total_base_amount_due total_txn_amount total_txn_amount_due
        dunning_count recurring_schedule payment_information is_system_generated_document
        e_invoice_status dispute refuse download_url allow_online_payment provider_payment
        retainage project_contract project_contract_billing architect
        project_contract_billing_invoice_summary entity web_url audit href
      ].freeze

      attr_accessor(*WRITABLE_ATTRIBUTES.keys)
      attr_accessor(*READONLY_ATTRIBUTES)
      attr_reader :custom_fields

      validate :presence, %i[invoice_date due_date]

      validate :kind_of, :string, %i[
        invoice_number state reference_number description invoice_date due_date
        invoice_type invoice_mode
      ]
      validate :kind_of, :hash, %i[
        currency customer_message contacts billback_template attachment customer term
        tax_solution invoice_summary
      ]
      validate :kind_of, :array, %i[lines]

      # source: an arbitrary domain object (ActiveRecord record, OpenStruct,
      # another Model::Invoice, ...) to pull matching attributes off of via
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
