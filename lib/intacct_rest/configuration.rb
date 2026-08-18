module IntacctRest
  class Configuration
    DEFAULT_BASE_URL       = "#{IntacctRest::API_URI}/#{IntacctRest::API_VERSION}".freeze
    DEFAULT_TOKEN_PATH     = '/oauth2/token'.freeze
    DEFAULT_QUERY_PATH     = '/services/core/query'.freeze
    DEFAULT_PAGE_SIZE      = 200
    DEFAULT_MAX_PAGES      = 50
    DEFAULT_TOKEN_KEY_PREFIX = 'intacct_rest:oauth'.freeze

    # Maps IntacctRest::Vendor's Ruby (snake_case) accessor names to the
    # exact camelCase JSON field names Intacct's vendor object uses. Kept
    # as explicit pairs rather than derived by a camelCase<->snake_case
    # regex, since a couple of fields have acronym runs a naive regex
    # would mangle (overrideOffsetGLAccount -> override_offset_g_l_account
    # instead of override_offset_gl_account). Excludes the deprecated
    # `accountlabel` alias in favor of `accountLabel`.
    DEFAULT_VENDOR_WRITABLE_ATTRIBUTES = {
      id: 'id', name: 'name', is_one_time_use: 'isOneTimeUse', status: 'status', state: 'state',
      vendor_type: 'vendorType', parent: 'parent', account_group: 'accountGroup',
      account_label: 'accountLabel', default_lead_time: 'defaultLeadTime',
      file_payment_service: 'filePaymentService', bank_files: 'bankFiles', tax_id: 'taxId',
      tpar: 'tpar', t5018: 't5018', form1099: 'form1099', attachment: 'attachment',
      is_on_hold: 'isOnHold', do_not_pay: 'doNotPay', always_create_bill: 'alwaysCreateBill',
      credit_limit: 'creditLimit', retainage_percentage: 'retainagePercentage',
      is_individual_person: 'isIndividualPerson', notes: 'notes', price_list: 'priceList',
      price_schedule: 'priceSchedule', override_offset_gl_account: 'overrideOffsetGLAccount',
      default_expense_gl_account: 'defaultExpenseGLAccount', discount_percent: 'discountPercent',
      contacts: 'contacts', contact_list: 'contactList',
      vendor_email_templates: 'vendorEmailTemplates', vendor_payment_providers: 'vendorPaymentProviders',
      vendor_bank_file_setup: 'vendorBankFileSetup', vendor_account_number_list: 'vendorAccountNumberList',
      preferred_payment_method: 'preferredPaymentMethod', merge_payment_requests: 'mergePaymentRequests',
      send_payment_notification: 'sendPaymentNotification', billing_type: 'billingType',
      payment_priority: 'paymentPriority', currency: 'currency',
      display_term_discount_on_check_stub: 'displayTermDiscountOnCheckStub', term: 'term',
      bill_payment: 'billPayment', vendor_account_number: 'vendorAccountNumber',
      display_vendor_account_on_check_stub: 'displayVendorAccountOnCheckStub', ach: 'ach',
      vendor_restriction: 'vendorRestriction', restricted_locations: 'restrictedLocations',
      restricted_departments: 'restrictedDepartments'
    }.freeze

    attr_accessor :client_id, :client_secret, :username, :base_url, :token_path,
                  :query_path, :token_store, :page_size, :max_pages, :token_key_prefix,
                  :on_error

    def initialize
      @base_url         = DEFAULT_BASE_URL
      @token_path       = DEFAULT_TOKEN_PATH
      @query_path       = DEFAULT_QUERY_PATH
      @page_size        = DEFAULT_PAGE_SIZE
      @max_pages        = DEFAULT_MAX_PAGES
      @token_key_prefix = DEFAULT_TOKEN_KEY_PREFIX
      @token_store      = IntacctRest::TokenStore::Memory.new
    end
  end
end
