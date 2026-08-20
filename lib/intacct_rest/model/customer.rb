# frozen_string_literal: true

module IntacctRest
  module Model
    # A customer's data and validations only — no config, no token
    # provider, no HTTP. Build and inspect one freely; IntacctRest::Post
    # (via IntacctRest::Endpoints::CreateCustomer) is what actually sends it.
    #
    # Nested objects (contacts, term, vendor, ...) are NOT individually
    # modeled — pass them as raw Hashes using Intacct's native (camelCase)
    # nested key names, e.g. term: { "id" => "Net 15" }. `vendor` is how a
    # customer references an associated vendor record, same raw-Hash
    # pattern: vendor: { "id" => "V-00014" }.
    class Customer < IntacctRest::Model::Base
      INTACCT_OBJECT = '/objects/accounts-receivable/customer'.freeze

      WRITABLE_ATTRIBUTES = IntacctRest::Configuration::DEFAULT_CUSTOMER_WRITABLE_ATTRIBUTES

      # Set by IntacctRest::Post after a successful create — writable here
      # even though Intacct itself treats them as read-only, since this is
      # the only place that result gets recorded.
      READONLY_ATTRIBUTES = %i[
        key href total_due last_invoice_created_date last_statement_generated_date
        subscription_end_date entity web_url audit
      ].freeze

      attr_accessor(*WRITABLE_ATTRIBUTES.keys)
      attr_accessor(*READONLY_ATTRIBUTES)
      attr_reader :custom_fields

      validate :presence, %i[name]

      validate :kind_of, :string, %i[
        id name status tax_id discount_percent advance_bill_by advance_bill_by_type
        customer_resale_number delivery_options override_price_list currency notes
        customer_restriction
      ]
      validate :kind_of, :boolean, %i[is_on_hold email_opt_in is_one_time_use disable_refund]
      validate :kind_of, :numeric, %i[credit_limit retainage_percentage]
      validate :kind_of, :hash, %i[
        customer_type parent sales_representative default_revenue_gl_account shipping_method
        contacts restrictions term customer_message territory vendor account_group
        account_label attachment price_list price_schedule override_offset_gl_account
        customer_account_health
      ]
      validate :kind_of, :array, %i[
        contact_list customer_email_templates restricted_locations restricted_departments
      ]

      # source: an arbitrary domain object (ActiveRecord record, OpenStruct,
      # another Model::Customer, ...) to pull matching attributes off of via
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
