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

    # Maps IntacctRest::Model::Invoice's Ruby (snake_case) accessor names
    # to the exact camelCase JSON field names Intacct's AR invoice object
    # uses. Nested objects (customer, lines, currency, ...) stay raw
    # Hashes — not individually modeled, same as Vendor's nested fields.
    DEFAULT_INVOICE_WRITABLE_ATTRIBUTES = {
      invoice_number: 'invoiceNumber', state: 'state', reference_number: 'referenceNumber',
      description: 'description', invoice_date: 'invoiceDate', due_date: 'dueDate',
      currency: 'currency', customer_message: 'customerMessage', contacts: 'contacts',
      billback_template: 'billbackTemplate', attachment: 'attachment', customer: 'customer',
      term: 'term', tax_solution: 'taxSolution', invoice_type: 'invoiceType',
      invoice_mode: 'invoiceMode', invoice_summary: 'invoiceSummary', lines: 'lines'
    }.freeze

    # Maps IntacctRest::Model::Term's Ruby (snake_case) accessor names to
    # the exact camelCase JSON field names Intacct's AR term object uses.
    # due/discount/penalty stay raw Hashes — not individually modeled.
    DEFAULT_TERM_WRITABLE_ATTRIBUTES = {
      id: 'id', status: 'status', description: 'description', due: 'due',
      discount: 'discount', penalty: 'penalty'
    }.freeze

    # Maps IntacctRest::Model::InvoiceLine's Ruby (snake_case) accessor
    # names to the exact camelCase JSON field names Intacct's AR invoice
    # line object uses. Nested objects (glAccount, dimensions, ...) stay
    # raw Hashes — not individually modeled.
    DEFAULT_INVOICE_LINE_WRITABLE_ATTRIBUTES = {
      gl_account: 'glAccount', override_offset_gl_account: 'overrideOffsetGLAccount',
      txn_amount: 'txnAmount', memo: 'memo', allocation: 'allocation',
      account_label: 'accountLabel', tax_entries: 'taxEntries', dimensions: 'dimensions',
      invoice: 'invoice'
    }.freeze

    # Maps IntacctRest::Model::Currency's Ruby (snake_case) accessor names
    # to the exact camelCase JSON field names used wherever a currency
    # object is nested (invoice header, invoice line, ...). Currency has
    # no standalone create endpoint of its own in Intacct's REST API — this
    # model exists purely to build/validate that nested Hash.
    DEFAULT_CURRENCY_ATTRIBUTES = {
      base_currency: 'baseCurrency', txn_currency: 'txnCurrency', exchange_rate: 'exchangeRate'
    }.freeze

    # Maps IntacctRest::Model::Customer's Ruby (snake_case) accessor names
    # to the exact camelCase JSON field names Intacct's customer object
    # uses. Excludes deprecated fields (electronicAddress, resaleNumber,
    # enableOnlineACHPayment, enableOnlineCardPayment, activationDate) in
    # favor of their replacements or because they're pure legacy no-ops —
    # same treatment as Vendor's deprecated `accountlabel`.
    DEFAULT_CUSTOMER_WRITABLE_ATTRIBUTES = {
      id: 'id', name: 'name', status: 'status', customer_type: 'customerType', parent: 'parent',
      sales_representative: 'salesRepresentative', tax_id: 'taxId',
      default_revenue_gl_account: 'defaultRevenueGLAccount', shipping_method: 'shippingMethod',
      credit_limit: 'creditLimit', is_on_hold: 'isOnHold', contacts: 'contacts',
      contact_list: 'contactList', restrictions: 'restrictions',
      customer_email_templates: 'customerEmailTemplates', discount_percent: 'discountPercent',
      term: 'term', advance_bill_by: 'advanceBillBy', advance_bill_by_type: 'advanceBillByType',
      customer_resale_number: 'customerResaleNumber', delivery_options: 'deliveryOptions',
      override_price_list: 'overridePriceList', customer_message: 'customerMessage',
      currency: 'currency', email_opt_in: 'emailOptIn', territory: 'territory',
      is_one_time_use: 'isOneTimeUse', disable_refund: 'disableRefund', vendor: 'vendor',
      account_group: 'accountGroup', account_label: 'accountLabel', attachment: 'attachment',
      retainage_percentage: 'retainagePercentage', notes: 'notes', price_list: 'priceList',
      price_schedule: 'priceSchedule', override_offset_gl_account: 'overrideOffsetGLAccount',
      customer_restriction: 'customerRestriction', restricted_locations: 'restrictedLocations',
      restricted_departments: 'restrictedDepartments', customer_account_health: 'customerAccountHealth'
    }.freeze

    # Maps IntacctRest::Model::Contact's Ruby (snake_case) accessor names
    # to the exact camelCase JSON field names Intacct's contact object
    # uses. Deliberately a small subset of the "contacts.default" nested
    # shape (which appears identically inside both the vendor and customer
    # specs) — every other field there (firstName, lastName, email1/2,
    # phone1/2, mobile, pager, fax, url1/2, companyName, mailingAddress,
    # ...) is individually marked deprecated: true in Intacct's schema, in
    # favor of referencing an existing contact by id. Contact has no
    # standalone create endpoint documented.
    DEFAULT_CONTACT_ATTRIBUTES = {
      id: 'id', show_in_contact_list: 'showInContactList', tax: 'tax',
      electronic_invoice_details: 'electronicInvoiceDetails',
      international_tax_id: 'internationalTaxId', electronic_address: 'electronicAddress'
    }.freeze

    # Maps IntacctRest::Model::Bill's Ruby (snake_case) accessor names to
    # the exact camelCase JSON field names Intacct's AP bill object uses.
    # Nested objects (vendor, term, currency, lines, ...) stay raw Hashes
    # — not individually modeled, same as Invoice's nested fields.
    # Excludes deprecated fields (`purchasing`, `location` — both marked
    # deprecated: true in the schema in favor of `purchasingDocument` and
    # nothing, respectively).
    DEFAULT_BILL_WRITABLE_ATTRIBUTES = {
      bill_number: 'billNumber', state: 'state', vendor: 'vendor', term: 'term',
      reference_number: 'referenceNumber', description: 'description', posting_date: 'postingDate',
      discount_cut_off_date: 'discountCutOffDate', due_date: 'dueDate',
      recommended_payment_date: 'recommendedPaymentDate', created_date: 'createdDate',
      is_on_hold: 'isOnHold', is_tax_inclusive: 'isTaxInclusive', payment_priority: 'paymentPriority',
      contacts: 'contacts', currency: 'currency', tax_solution: 'taxSolution',
      invoice_type: 'invoiceType', invoice_mode: 'invoiceMode', bill_summary: 'billSummary',
      bill_back_template: 'billBackTemplate', attachment: 'attachment', lines: 'lines',
      dispute: 'dispute', refuse: 'refuse'
    }.freeze

    # Maps IntacctRest::Model::BillLine's Ruby (snake_case) accessor names
    # to the exact camelCase JSON field names Intacct's AP bill line
    # object uses. Nested objects (glAccount, dimensions, ...) stay raw
    # Hashes — not individually modeled.
    DEFAULT_BILL_LINE_WRITABLE_ATTRIBUTES = {
      vendor: 'vendor', gl_account: 'glAccount', override_offset_gl_account: 'overrideOffsetGLAccount',
      account_label: 'accountLabel', txn_amount: 'txnAmount', total_txn_amount: 'totalTxnAmount',
      memo: 'memo', allocation: 'allocation', has_form1099: 'hasForm1099', form1099: 'form1099',
      release_to_pay: 'releaseToPay', project: 'project', fixed_asset: 'fixedAsset',
      amortization_template: 'amortizationTemplate', amortization_start_date: 'amortizationStartDate',
      amortization_end_date: 'amortizationEndDate', purchasing: 'purchasing',
      tax_entries: 'taxEntries', dimensions: 'dimensions', bill: 'bill'
    }.freeze

    attr_accessor :client_id, :client_secret, :username, :base_url, :token_path,
                  :query_path, :token_store, :page_size, :max_pages, :token_key_prefix,
                  :on_error, :schema

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
