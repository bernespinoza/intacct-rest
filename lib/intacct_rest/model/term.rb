# frozen_string_literal: true

module IntacctRest
  module Model
    # An AR term's data and validations only — no config, no token
    # provider, no HTTP. Build and inspect one freely; IntacctRest::Post
    # (via IntacctRest::Endpoints::CreateTerm) is what actually sends it.
    #
    # Nested objects (due, discount, penalty) are NOT individually
    # modeled — pass them as raw Hashes using Intacct's native (camelCase)
    # nested key names, e.g. due: { "days" => 30, "from" => "fromInvoiceDate" }.
    class Term < IntacctRest::Model::Base
      INTACCT_OBJECT = '/objects/accounts-receivable/term'.freeze

      WRITABLE_ATTRIBUTES = IntacctRest::Configuration::DEFAULT_TERM_WRITABLE_ATTRIBUTES

      READONLY_ATTRIBUTES = %i[key href audit].freeze

      attr_accessor(*WRITABLE_ATTRIBUTES.keys)
      attr_accessor(*READONLY_ATTRIBUTES)
      attr_reader :custom_fields

      validate :presence, %i[id description]
      validate :kind_of, :string, %i[id status description]
      validate :kind_of, :hash, %i[due discount penalty]

      # source: an arbitrary domain object to pull matching attributes off
      # of via duck-typing. Explicit keyword attributes always win.
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
