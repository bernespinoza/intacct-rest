# IntacctRest

A small, framework-agnostic Ruby client for [Sage Intacct's REST API v1](https://developer.sage.com/intacct/docs/1/sage-intacct-rest-api). It wraps:

- **OAuth2 token handling** (`client_credentials` and `refresh_token` grants), with pluggable token storage
- **The `POST /services/core/query` endpoint**, for any Intacct object (invoices, bills, customers, ...), with pagination and a small filter-operator builder
- **The `POST /objects/accounts-payable/vendor` endpoint**, via `IntacctRest::Endpoints::CreateVendor` (the use case), `IntacctRest::Post` (the generic, reusable "send this model" operation), and `IntacctRest::Model::Vendor` (the data + a small declarative validation DSL), covering every vendor field plus custom fields
- **The `PATCH /objects/accounts-payable/vendor/{key}` endpoint**, via `IntacctRest::Endpoints::UpdateVendor` and `IntacctRest::Patch` (the generic "update this model" operation), sending only the fields you set
- **The `POST /objects/accounts-receivable/invoice` endpoint**, via `IntacctRest::Endpoints::CreateInvoice` and `IntacctRest::Model::Invoice`, reusing the same `Post`/validation pattern
- **The `POST /objects/accounts-receivable/term` endpoint**, via `IntacctRest::Endpoints::CreateTerm` and `IntacctRest::Model::Term`
- **The `POST /objects/accounts-receivable/invoice-line` endpoint**, via `IntacctRest::Endpoints::CreateInvoiceLine` and `IntacctRest::Model::InvoiceLine`
- **`IntacctRest::Model::Currency`**, a data + validation object for the currency shape shared by invoices and invoice lines (no dedicated create endpoint — Intacct manages currencies elsewhere; this is just a typed helper for building the payload)
- **The `POST /objects/accounts-receivable/customer` endpoint**, via `IntacctRest::Endpoints::CreateCustomer` and `IntacctRest::Model::Customer`, reusing the same `Post`/validation pattern
- **`IntacctRest::Model::Contact`**, a data + validation object for the non-deprecated subset of the contact shape shared by vendors and customers (no dedicated create endpoint — contacts are referenced by id from `contacts`/`contact_list`; this is just a typed helper for building that nested payload)
- **The `POST /objects/accounts-payable/bill` endpoint**, via `IntacctRest::Endpoints::CreateBill` and `IntacctRest::Model::Bill`, reusing the same `Post`/validation pattern
- **The `POST /objects/accounts-payable/bill-line` endpoint**, via `IntacctRest::Endpoints::CreateBillLine` and `IntacctRest::Model::BillLine`

It has no Rails, ActiveRecord, or Redis dependency — the host application supplies its own token store and error-handling hook.

## Installation

```ruby
gem "intacct-rest", github: "bernespinoza/intacct-rest", tag: "v1.0.0"
```

Publishing to RubyGems is planned; until then, install from GitHub.

## Configuration

```ruby
IntacctRest.configure do |config|
  config.client_id     = ENV.fetch("INTACCT_OAUTH_CLIENT_ID")
  config.client_secret = ENV.fetch("INTACCT_OAUTH_CLIENT_SECRET")
  config.username      = ENV.fetch("INTACCT_OAUTH_USERNAME")

  # Optional — all of these have sane defaults (see IntacctRest::Configuration):
  # config.base_url         = "https://api.intacct.com/ia/api/v1"
  # config.token_path       = "/oauth2/token"
  # config.query_path       = "/services/core/query"
  # config.page_size        = 200
  # config.max_pages        = 50
  # config.token_key_prefix = "intacct_rest:oauth"

  # Token storage defaults to an in-memory store (IntacctRest::TokenStore::Memory).
  # Swap in your own — anything responding to #read(key), #write(key, value, ttl:), #delete(key):
  config.token_store = MyApp::RedisTokenStore.new(Redis.new(url: ENV.fetch("REDIS_URL")))

  # Optional. Called with (error, context:) right before the gem raises an ApiError from
  # an Intacct request (non-2xx response or ia::error payload), an AuthenticationError,
  # a ResponseParseError, or a SchemaLoadError — wire this to your own logging/
  # instrumentation. context: holds only operation (:api_request, :token_request,
  # :schema_load), path, and http_status / grant_type when known — never credentials,
  # tokens or bodies. Not called for errors the gem recovers from (a failed refresh
  # falling back to client_credentials), errors raised before any request
  # (ValidationError, ArgumentError), the results: check on endpoints, or non-2xx
  # Results from Post/Patch. Exceptions raised by your hook are ignored, and the
  # original error is raised unchanged. The gem never logs on its own.
  config.on_error = ->(error, context:) { MyApp::Logger.warn(error.message, context) }

  # A Hash or a YAML file path — see "Schema" below. Defaults to nil (empty).
  config.schema = "config/intacct_schema.yml"
end
```

### Writing a custom token store

```ruby
class RedisTokenStore
  def initialize(redis)
    @redis = redis
  end

  def read(key)
    @redis.get(key)
  rescue Redis::BaseError
    nil
  end

  def write(key, value, ttl: nil)
    ttl ? @redis.set(key, value, ex: ttl) : @redis.set(key, value)
  rescue Redis::BaseError
    nil
  end

  def delete(key)
    @redis.del(key)
  rescue Redis::BaseError
    nil
  end
end
```

## Querying

### A single page

```ruby
query = IntacctRest::Query.new(
  resource: "accounts-receivable/invoice",
  schema:   %w[key invoiceNumber state],
  filters:  [
    IntacctRest::Filter.eq("state", "paid"),
    IntacctRest::Filter.gt("audit.modifiedDateTime", "2026-01-01")
  ]
)

page = query.call
page.items       # => Array<Hash>
page.next_cursor # => String or nil
```

### Paginating

```ruby
IntacctRest::Query.new(resource: "accounts-receivable/invoice", schema: %w[key state])
                  .each_page(max_pages: 50) do |items, next_cursor|
  items.each { |invoice| ... }
end
```

`each_page` raises `IntacctRest::TooManyPagesError` if `max_pages` is exceeded, rather than silently truncating results.

## Objects API

`IntacctRest::Objects` reads records straight from the objects API:

```ruby
objects = IntacctRest::Objects.new
objects.list("accounts-receivable/invoice")        # => Array<Hash> (first page, no pagination)
objects.find("accounts-receivable/invoice", "42")   # => Hash (single record)
```

## Schema

`IntacctRest::SchemaGenerator` discovers a resource's fields by sampling **one real record**
(list → pick one key → fetch it → flatten its keys, nested Hashes dot-joined, e.g.
`paymentInformation.fullyPaidDate`). This is a **lower bound, not a guarantee of
completeness** — any field that's nil/empty on the sampled record won't appear (a nil
`paymentInformation` collapses to one bare `paymentInformation` leaf instead of its nested
fields), and there's no confirmed sort order on the list endpoint, so the auto-picked record
is an arbitrary sample, not "the latest." Treat its output as a starting point to hand-review
and merge, not as ground truth to commit blindly. Pass `key:` to override the auto-picked
sample with a known-good record.

The gem itself has no opinion on what resources you care about — you supply the mapping:

```ruby
generator = IntacctRest::SchemaGenerator.new
resources = { invoices: "accounts-receivable/invoice", payments: "accounts-receivable/payment" }

generator.generate("accounts-receivable/invoice")        # => Array<String>
generator.generate_all(resources)                         # => {invoices: [...], payments: [...]}
generator.write("config/intacct_schema.yml", resources)   # dumps YAML, overwrites unconditionally
```

Written YAML looks like:

```yaml
invoices:
  - key
  - state
  - paymentInformation.fullyPaidDate
payments:
  - key
  - amount
```

`IntacctRest::SchemaSource` resolves `Configuration#schema` (a Hash, a YAML path, or nil)
into field arrays for use as `Query#schema:`. Not auto-wired into `Query` — pass it explicitly
so `Query` stays resource-agnostic:

```ruby
fields = IntacctRest::SchemaSource.new(IntacctRest.configuration.schema).for(:invoices)
IntacctRest::Query.new(resource: "accounts-receivable/invoice", schema: fields, ...)
```

## Creating a vendor

Three pieces work together, each with one job:

- **`IntacctRest::Model::Vendor`** — the vendor's data and validations. No config, no token provider, no HTTP knowledge. Build one, inspect it, `valid?`/`errors` it, all without touching the network.
- **`IntacctRest::Post`** — a generic "send this model" operation. Works against *any* model that responds to `#intacct_object` (the endpoint path), `#payload` (the outgoing JSON), `#errors(:create)`, and `#apply_result` — not specific to vendors.
- **`IntacctRest::Endpoints::CreateVendor`** — the vendor-specific use case: calls `Post`, then checks the response actually contains the fields you expect.

`IntacctRest::Model::Vendor` exposes every field from Sage Intacct's vendor object as a Ruby-idiomatic snake_case accessor (`is_one_time_use`, `default_lead_time`, `vendor_account_number`, ...), mapped to Intacct's exact camelCase JSON key when `#payload` builds the request — see `IntacctRest::Configuration::DEFAULT_VENDOR_WRITABLE_ATTRIBUTES` for the full name mapping. Nested objects (`bank_files`, `contacts`, `term`, `bill_payment`, ...) are **not** individually modeled — pass them as raw Hashes using Intacct's native (camelCase) nested key names, as shown for `term` below.

```ruby
vendor = IntacctRest::Model::Vendor.new(
  id:           "V-00014",
  name:         "NCS, Inc.",
  credit_limit: 40_000,
  is_on_hold:   false,
  term:         { "id" => "Net 30" }
)

vendor.key # => nil (not created yet)

result = IntacctRest::Endpoints::CreateVendor.call(vendor: vendor, results: %i[id key href])

result.success? # => true
vendor.key      # => "111"       (written onto the model by Post, via model.apply_result)
vendor.href     # => "/objects/accounts-payable/vendor/111"
```

You can also build the outgoing JSON payload without sending anything, e.g. for debugging:

```ruby
vendor.payload.to_json # => {"id":"V-00014","name":"NCS, Inc.","isOnHold":false,"creditLimit":40000,"term":{"id":"Net 30"}}
```

### Building a model from an existing object

`Model::Vendor.new` also accepts a single positional "source" object — an ActiveRecord record, an `OpenStruct`, another `Model::Vendor` — and pulls any matching attribute off it via duck-typing (`source.respond_to?(attr)`). Explicit keyword attributes always win over whatever the source provided:

```ruby
vendor = IntacctRest::Model::Vendor.new(some_ar_vendor, credit_limit: 1_000) # override just one field
```

### The Result

`IntacctRest::Post` and `IntacctRest::Patch` (and therefore every endpoint) never raise for the HTTP outcome itself — they always return an `IntacctRest::Result` (`Result::Success` or `Result::Error`), each responding to `#code`, `#body`, `#response` (alias for `#body`), `#headers`, `#model`, and `#success?`/`#failed?`:

```ruby
result = IntacctRest::Endpoints::CreateVendor.call(vendor: vendor)

if result.success?
  result.key   # => "111"  — dynamic access into the response's ia::result
  result.href
else
  result.error # => the parsed ia::error payload
end
```

What still raises, before any request is sent or when something is actually broken (not just "Intacct rejected this vendor"):

- `ArgumentError` — an endpoint got the wrong kind of model (e.g. `CreateVendor`/`UpdateVendor` with a `vendor:` that isn't a `Model::Vendor`)
- `IntacctRest::ValidationError` — the model is invalid (see Validation, below)
- `IntacctRest::AuthenticationError` — a request 401'd even after a token refresh
- `IntacctRest::ResponseParseError` — the response body wasn't valid JSON
- `IntacctRest::ApiError` (from any endpoint that takes `results:` — `CreateVendor`, `UpdateVendor`, `CreateInvoice`, ...) — a *successful* response was missing one of the fields declared in `results:`

### Validation

`IntacctRest::Model::Vendor` declares its validations with a small DSL (`IntacctRest::Model::Base`, shared by any future model) — each declaration is `validate :kind, *options, [:attr, ...], on: context`:

```ruby
validate :presence, %i[id name], on: :create
validate :presence, %i[key], on: :update
validate :kind_of, :string, %i[key], on: :update

validate :kind_of, :string, %i[id name status state ...]
validate :inclusion, BANK_FILE_COUNTRY_CODES, %i[bank_files_payment_country_code]
```

`on:` scopes a validation to one operation: it only runs when `#errors`/`#valid?` is called with that context. A validation without `on:` always runs. `Post` validates with `:create` and `Patch` with `:update`, so a vendor needs `id`/`name` to be created and `key` to be updated (see Updating a vendor, below).

Four validator kinds ship in `IntacctRest::Validators`:

- `:presence` — the attribute must not be `nil`
- `:kind_of` — the attribute, if present, must be one of a small set of types (`:string`, `:integer`, `:numeric`, `:float`, `:boolean`, `:hash`, `:array`, `:date`, `:time`)
- `:inclusion` — the attribute, if present, must be included in a given list (e.g. Intacct's documented bank-file country codes)
- `:custom` — the attribute, if present, is passed to an instance method you name (`record.send(method_name, value)`); a falsy return means invalid

By default, `Post` validates the model first, raising `IntacctRest::ValidationError` and skipping the HTTP request entirely if it's invalid — currently that means `id`/`name` presence, every field's documented type, and `bank_files["paymentCountryCode"]` (if set) matching a real country code. `Patch` does the same with `key` in place of `id`/`name`. Note Intacct can auto-generate `id` when document sequencing is enabled for your company; override `errors` in a `Model::Vendor` subclass if you need to relax that.

### Custom fields

`custom_fields` is a collection of `IntacctRest::CustomField` (`namespace`/`name`/`value`), serialized as `"#{namespace}::#{name}"`. The namespace defaults to `"nsp"`:

```ruby
IntacctRest::Model::Vendor.new(
  id: "V-00014",
  name: "NCS, Inc.",
  custom_fields: [IntacctRest::CustomField.new(name: "preferredCourier", value: "UPS")]
)
# payload includes: "nsp::preferredCourier" => "UPS"
```

A flat Hash also works as shorthand — each entry becomes a `CustomField` with the default `"nsp"` namespace:

```ruby
IntacctRest::Model::Vendor.new(id: "V-00014", name: "NCS, Inc.", custom_fields: { "preferredCourier" => "UPS" })
```

### Subclassing for extra validation

Subclass `IntacctRest::Model::Vendor` and add your own `validate` declarations — they accumulate on top of the built-in ones:

```ruby
class StrictVendor < IntacctRest::Model::Vendor
  validate :presence, %i[tax_id]
end

IntacctRest::Endpoints::CreateVendor.call(vendor: StrictVendor.new(id: "V-00014", name: "NCS, Inc."))
# => raises IntacctRest::ValidationError ("tax_id is required"), no request sent
```

## Updating a vendor

`IntacctRest::Endpoints::UpdateVendor` sends `PATCH /objects/accounts-payable/vendor/{key}`. Set `key` to pick the record, plus only the fields you want to change:

```ruby
vendor = IntacctRest::Model::Vendor.new(key: "111", credit_limit: 10_000)

vendor.update_payload.to_json # => {"creditLimit":10000}

result = IntacctRest::Endpoints::UpdateVendor.call(vendor: vendor, results: %i[id key href])

result.success? # => true
vendor.id       # => "V-00014"   (filled in from the response by Patch, via model.apply_result)
```

- `key` is required on update and must be a String. `id` is read-only on update (`Model::Vendor::UPDATE_READONLY_ATTRIBUTES`), so it's left out of the request body even when set.
- Only the fields you set are sent (`#update_payload`); anything left `nil` stays unchanged in Intacct. That also means a PATCH can't clear a field to null — `nil` is never sent — while `false` and `""` are sent as is (and `""` can blank a field in Intacct).
- `results:` works the same as on create: it defaults to `%i[id key href]`, and a successful response missing one of them raises `IntacctRest::ApiError`. A failed Result skips the check.
- On success, `apply_result` writes the response back onto the model: `key` and `href` whenever the response has them, and `id` only when it isn't already set.

### IntacctRest::Patch

`IntacctRest::Patch` is the generic "update this model" operation behind `UpdateVendor`, the PATCH counterpart of `Post`. It works against any model that responds to:

- `#intacct_object` — the collection path; `Patch` appends `/#{model.key}`
- `#key` — the record to update
- `#update_payload` — the outgoing JSON, only the fields to change
- `#errors(:update)` — validated first; any error raises `IntacctRest::ValidationError` and no request is sent
- `#apply_result` — called with the Result on success

Like `Post`, it never raises for the HTTP outcome and always returns an `IntacctRest::Result` (see The Result, above).

## Creating an invoice

Same three pieces as vendors — `IntacctRest::Model::Invoice` (data + validation), `IntacctRest::Post` (generic send), `IntacctRest::Endpoints::CreateInvoice` (the invoice-specific use case):

```ruby
invoice = IntacctRest::Model::Invoice.new(
  invoice_date: "2022-12-06",
  due_date:     "2022-12-31",
  customer:     { "id" => "C-00019" },
  lines: [
    { "txnAmount" => "100.40", "glAccount" => { "id" => "5004" } }
  ]
)

result = IntacctRest::Endpoints::CreateInvoice.call(invoice: invoice, results: %i[id key href])

result.success? # => true
invoice.key     # => "2091"
invoice.href    # => "/objects/accounts-receivable/invoice/2091"
```

`customer` is how an invoice references an existing customer record — like every other nested object in this gem, it's a raw Hash (`{"id" => "..."}`) using Intacct's native key names, not a `Model::Customer` instance; there's no code-level dependency between `Model::Invoice` and `Model::Customer`. Same for `lines` — an Array of raw line-item Hashes (see the [Invoice API docs](https://developer.sage.com/intacct/docs/1/sage-intacct-rest-api) for the full line-item shape). Only `invoice_date` and `due_date` are validated as required at this layer; nested required fields (`customer.id`, `lines[].txnAmount`, ...) are left to Intacct's own validation — the same nested-fields boundary as vendors' `bank_files`/`term`/etc.

`term` (payment terms) and `currency` on `Model::Invoice` follow the same rule — they stay plain Hashes on the invoice itself, so nothing about `Model::Invoice` changes. `Model::Term`, `Model::InvoiceLine`, and `Model::Currency` below are separate, optional objects for the cases where you want validation and a typed `#payload` for those pieces individually (e.g. creating a new term, or building an invoice line before nesting its `#payload` into `invoice.lines`) — you're never required to use them.

## Creating a term

```ruby
term = IntacctRest::Model::Term.new(
  id:          "2-10 Net 30",
  description: "N30 with discount",
  due:         { "days" => 30, "from" => "fromInvoiceDate" }
)

result = IntacctRest::Endpoints::CreateTerm.call(term: term, results: %i[id key href])

result.success? # => true
term.key        # => "18"
```

`id` and `description` are required; `due`, `discount`, and `penalty` are raw Hashes, same nested-fields boundary as everywhere else in this gem.

## Creating an invoice line

`IntacctRest::Model::InvoiceLine` wraps `POST /objects/accounts-receivable/invoice-line` directly, for adding a line to an existing invoice (referenced by `invoice:`):

```ruby
line = IntacctRest::Model::InvoiceLine.new(
  invoice:    { "key" => "350" },
  txn_amount: "70.00",
  gl_account: { "id" => "4000" }
)

result = IntacctRest::Endpoints::CreateInvoiceLine.call(invoice_line: line, results: %i[id key href])

result.success? # => true
line.key        # => "806"
```

`invoice`, `txn_amount`, and `gl_account` are required. `currency` is read-only on a line (Intacct derives it from the invoice), so it isn't a writable attribute here even though it is on `Model::Invoice`'s header.

To instead build a line as part of a new invoice's `lines:` array, use `line.payload` (or just a raw Hash — both work, since `Model::Invoice#lines` stays a plain Array):

```ruby
IntacctRest::Model::Invoice.new(
  invoice_date: "2022-12-06",
  due_date:     "2022-12-31",
  customer:     { "id" => "C-00019" },
  lines:        [line.payload]
)
```

## Currency

`IntacctRest::Model::Currency` has no create endpoint of its own — it's a small typed helper for the currency shape that appears on invoices and other objects:

```ruby
currency = IntacctRest::Model::Currency.new(
  txn_currency:  "USD",
  exchange_rate: { "date" => "2022-12-06", "typeId" => "Intacct Daily Rate", "rate" => 0.05112 }
)

currency.payload # => {"txnCurrency"=>"USD", "exchangeRate"=>{"date"=>"2022-12-06", "typeId"=>"Intacct Daily Rate", "rate"=>0.05112}}
```

Assign `currency.payload` (or a raw Hash) to `Model::Invoice#currency` the same way as `term`/`customer`.

## Creating a customer

Same three pieces as vendors — `IntacctRest::Model::Customer` (data + validation), `IntacctRest::Post` (generic send), `IntacctRest::Endpoints::CreateCustomer` (the customer-specific use case):

```ruby
customer = IntacctRest::Model::Customer.new(
  id:           "CUST-002",
  name:         "Starluck",
  tax_id:       "12-3456789",
  credit_limit: 50_000,
  status:       "active"
)

result = IntacctRest::Endpoints::CreateCustomer.call(customer: customer, results: %i[id key href])

result.success? # => true
customer.key    # => "32"
customer.href   # => "/objects/accounts-receivable/customer/32"
```

`vendor` is how a customer references an associated vendor record — like every other nested object in this gem, it's a raw Hash (`{"id" => "..."}`), not a `Model::Vendor` instance; there's no code-level dependency between `Model::Customer` and `Model::Vendor`. Only `name` is required at this layer, matching the schema's own `required: [name]`.

`contacts`/`contact_list` follow the same rule — they stay plain Hashes/Arrays on `Model::Customer` itself, so nothing about `Model::Customer` changes. `Model::Contact` below is a separate, optional object for the case where you want validation and a typed `#payload` for a contact individually — you're never required to use it.

## Contact

`IntacctRest::Model::Contact` has no create endpoint of its own — Intacct references an existing contact by `id` from a vendor's or customer's `contacts`/`contact_list` fields rather than creating one inline. It only exposes the *non-deprecated* subset of the "contacts.default" nested shape (`id`, `showInContactList`, `tax`, `electronicInvoiceDetails`, `internationalTaxId`, `electronicAddress`) — every richer field (`firstName`, `email1`, `phone1`, `mailingAddress`, ...) is individually marked `deprecated: true` in Intacct's schema:

```ruby
contact = IntacctRest::Model::Contact.new(id: "C-001", show_in_contact_list: true)

contact.payload # => {"id"=>"C-001", "showInContactList"=>true}
```

Assign `contact.payload` (or a raw Hash) into `Model::Customer#contacts`/`#contact_list` the same way as `vendor`/`term`.

## Creating a bill

Same three pieces as invoices — `IntacctRest::Model::Bill` (data + validation), `IntacctRest::Post` (generic send), `IntacctRest::Endpoints::CreateBill` (the bill-specific use case):

```ruby
bill = IntacctRest::Model::Bill.new(
  due_date:     "2024-03-08",
  created_date: "2024-02-21",
  vendor:       { "id" => "1099 Int" },
  currency:     { "baseCurrency" => "USD", "txnCurrency" => "USD" },
  lines: [
    { "txnAmount" => "5", "glAccount" => { "id" => "6000" } }
  ]
)

result = IntacctRest::Endpoints::CreateBill.call(bill: bill, results: %i[id key href])

result.success? # => true
bill.key        # => "299"
bill.href       # => "/objects/accounts-payable/bill/299"
```

`vendor` is how a bill references an existing vendor record — like every other nested object in this gem, it's a raw Hash (`{"id" => "..."}`), not a `Model::Vendor` instance. Same for `lines`, `term`, and `currency`. Only `due_date` and `created_date` are validated as required at this layer, matching the schema's own `required: [dueDate, createdDate]`; nested required fields (`vendor.id`, `currency.txnCurrency`, `lines[].txnAmount`/`glAccount`, `lines[].dimensions.location`) are left to Intacct's own validation — the same nested-fields boundary as invoices' `customer`/`lines`.

## Creating a bill line

`IntacctRest::Model::BillLine` wraps `POST /objects/accounts-payable/bill-line` directly, for adding a line to an existing bill (referenced by `bill:`):

```ruby
line = IntacctRest::Model::BillLine.new(
  bill:       { "key" => "19876" },
  txn_amount: "5",
  gl_account: { "id" => "6000" }
)

result = IntacctRest::Endpoints::CreateBillLine.call(bill_line: line, results: %i[id key href])

result.success? # => true
line.key        # => "1955"
```

`bill`, `txn_amount`, and `gl_account` are required. To instead build a line as part of a new bill's `lines:` array, use `line.payload` (or just a raw Hash — both work, since `Model::Bill#lines` stays a plain Array), the same way as `Model::InvoiceLine`.

## Errors

All exceptions inherit from `IntacctRest::Error`:

- `IntacctRest::AuthenticationError` — token request failed, or a request 401'd even after a token refresh
- `IntacctRest::ApiError` — `Query`: non-2xx response or an `ia::error` payload (`#http_status`, `#body`). `Endpoints::CreateVendor`/`CreateInvoice`/`CreateTerm`/`CreateInvoiceLine`/`CreateCustomer`/`CreateBill`/`CreateBillLine`/`UpdateVendor`: a successful response was missing a field declared in `results:`
- `IntacctRest::ResponseParseError` — response body wasn't valid JSON (`#raw_body`)
- `IntacctRest::ValidationError` — a model failed validation before any request was sent (`#attributes`)
- `IntacctRest::TooManyPagesError` — `each_page` exceeded `max_pages` (`#pages_fetched`)
- `IntacctRest::SchemaGenerationError` — `SchemaGenerator` found no records to sample
- `IntacctRest::SchemaLoadError` — `SchemaSource` failed to read/parse a YAML file

Non-2xx responses from `IntacctRest::Post`/`IntacctRest::Patch` and any endpoint are **not** exceptions — they come back as a Result (see The Result, above).

## Development

```sh
bundle install
bundle exec rake test
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/bernespinoza/intacct-rest. Please open an issue first; see [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
