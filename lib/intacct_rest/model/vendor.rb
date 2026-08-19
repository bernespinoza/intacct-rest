# frozen_string_literal: true

module IntacctRest
  module Model
    # The vendor's data and validations only — no config, no token
    # provider, no HTTP. Build and inspect one freely; IntacctRest::Post
    # (via IntacctRest::Endpoints::CreateVendor) is what actually sends it.
    #
    # Nested objects (bank_files, contacts, term, bill_payment, ...) are
    # pass them as raw Hashes Intacct's
    # native (camelCase) nested key names, e.g. term: { "id" => "Net 30" }. Or passes a
    # model instace for them.
    class Vendor < IntacctRest::Model::Base
      INTACCT_OBJECT = '/objects/accounts-payable/vendor'.freeze

      WRITABLE_ATTRIBUTES = IntacctRest::Configuration::DEFAULT_VENDOR_WRITABLE_ATTRIBUTES

      # Set by IntacctRest::Post (via #apply_result) after a successful
      # create — writable here even though Intacct itself treats them as
      # read-only, since this is the only place that result gets recorded.
      READONLY_ATTRIBUTES = %i[
        key href is_system_generated customer employee total_due last_bill_created_date
        last_payment_made_date web_url audit entity
      ].freeze

      # The exact enum from the OpenAPI bankFiles.paymentCountryCode /
      # country-code schema (nil is separately allowed by the :inclusion
      # validator below — not listed here).
      BANK_FILE_COUNTRY_CODES = %w[
        us af ax al dz as ad ao ai aq ag ar am aw au at az bs bh bd bb by be bz bj bm bt bo bq ba
        bw bv br io bn bg bf bi kh cm ca ic cv ky cf td cl cn cx cc co km cg cd ck cr ci hr cu cw
        cy cz dk dj dm do ec eg sv gq er ee sz et fk fo fj fi fr gf pf tf ga gm ge de gh gi gr gl
        gd gp gu gt gg gn gw gy ht hm hn hk hu is in id ir iq ie im il it jm jp je jo kz ke ki kr
        kp xk kw kg la lv lb ls lr ly li lt lu mo mk mg mw my mv ml mt mh mq mr mu yt mx fm md mc
        mn me ms ma mz mm na nr np nl an nc nz ni ne ng nu nf mp no om pk pw ps pa pg py pe ph pn
        pl pt pr qa re ro ru rw bl sh kn lc mf pm vc ws sm st sa sn rs sc sl sg sx sk si sb so za
        gs es lk sd ss sr sj se ch sy tw tj tz th tl tg tk to tt tn tr tm tc tv ug ua ae gb um uy
        uz vu va ve vn vg vi wf eh ye zm zw
      ].freeze

      attr_accessor(*WRITABLE_ATTRIBUTES.keys)
      attr_accessor(*READONLY_ATTRIBUTES)
      attr_reader :custom_fields

      validate :presence, %i[id name]

      validate :kind_of, :string, %i[
        id name status state file_payment_service tax_id notes preferred_payment_method
        billing_type payment_priority currency vendor_account_number vendor_restriction
      ]
      validate :kind_of, :boolean, %i[
        is_one_time_use is_on_hold do_not_pay always_create_bill is_individual_person
        merge_payment_requests send_payment_notification display_term_discount_on_check_stub
        display_vendor_account_on_check_stub
      ]
      validate :kind_of, :integer, %i[default_lead_time]
      validate :kind_of, :numeric, %i[credit_limit retainage_percentage discount_percent]
      validate :kind_of, :hash, %i[
        vendor_type parent account_group account_label bank_files tpar t5018 form1099 attachment
        price_list price_schedule override_offset_gl_account default_expense_gl_account contacts
        term bill_payment ach
      ]
      validate :kind_of, :array, %i[
        contact_list vendor_email_templates vendor_payment_providers vendor_bank_file_setup
        vendor_account_number_list restricted_locations restricted_departments
      ]

      validate :inclusion, BANK_FILE_COUNTRY_CODES, %i[bank_files_payment_country_code]

      # source: an arbitrary domain object (ActiveRecord record, OpenStruct,
      # another Model::Vendor, ...) to pull matching attributes off of via
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

      # Virtual attribute so the generic :inclusion validator can point at
      # a nested field — bank_files itself stays a raw Hash (see above), so
      # this just digs the one field out of it, tolerating string or
      # symbol keys.
      def bank_files_payment_country_code
        return nil unless bank_files

        bank_files['paymentCountryCode'] || bank_files[:paymentCountryCode]
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
