# frozen_string_literal: true

module IntacctRest
  module Model
    # The vendor's data and validations only — no config, no token
    # provider, no HTTP. Build and inspect one freely; IntacctRest::Vendor
    # is what actually sends it.
    #
    # Nested objects (bank_files, contacts, term, bill_payment, ...) are
    # NOT individually modeled — pass them as raw Hashes using Intacct's
    # native (camelCase) nested key names, e.g. term: { "id" => "Net 30" }.
    class Vendor < IntacctRest::Model::Base
      WRITABLE_ATTRIBUTES = IntacctRest::Configuration::DEFAULT_VENDOR_WRITABLE_ATTRIBUTES

      # Set by IntacctRest::Vendor after a successful create — writable
      # here even though Intacct itself treats them as read-only, since
      # this is the only place that result gets recorded.
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
      attr_accessor :custom_fields

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

      def initialize(custom_fields: {}, **attributes)
        @custom_fields = custom_fields
        attributes.each { |key, value| public_send(:"#{key}=", value) }
      end

      # Virtual attribute so the generic :inclusion validator can point at
      # a nested field — bank_files itself stays a raw Hash (see above), so
      # this just digs the one field out of it, tolerating string or
      # symbol keys.
      def bank_files_payment_country_code
        return nil unless bank_files

        bank_files['paymentCountryCode'] || bank_files[:paymentCountryCode]
      end
    end
  end
end
