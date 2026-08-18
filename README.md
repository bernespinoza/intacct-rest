# IntacctRest

A small, framework-agnostic Ruby client for [Sage Intacct's REST API v1](https://developer.sage.com/intacct/docs/1/sage-intacct-rest-api). It wraps:

- **OAuth2 token handling** (`client_credentials` and `refresh_token` grants), with pluggable token storage
- **The `POST /services/core/query` endpoint**, for any Intacct object (invoices, bills, customers, ...), with pagination and a small filter-operator builder
- **The `POST /objects/accounts-payable/vendor` endpoint**, via `IntacctRest::Vendor` (the operation) and `IntacctRest::Model::Vendor` (the data + a small declarative validation DSL), covering every vendor field plus custom fields

It has no Rails, ActiveRecord, or Redis dependency — the host application supplies its own token store and error-handling hook.

## Installation

```ruby
gem "intacct-rest", path: "../intacct_rest" # or a git source once this has a remote
```

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

  # Called whenever the gem rescues (and re-raises) an error — wire this to your own
  # logging/instrumentation. The gem never logs on its own.
  config.on_error = ->(error, context:) { MyApp::Logger.warn(error.message, context) }
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

## Creating a vendor

```ruby
vendor = IntacctRest::Vendor.call(
  id:           "V-00014",
  name:         "NCS, Inc.",
  credit_limit: 40_000,
  is_on_hold:   false,
  term:         { "id" => "Net 30" }
)

vendor.key  # => "111"
vendor.href # => "/objects/accounts-payable/vendor/111"
```

`IntacctRest::Vendor.call` is a thin operation object — it doesn't hold vendor data itself. It builds (or accepts) an `IntacctRest::Model::Vendor`, which is where every field from Sage Intacct's vendor object lives as a Ruby-idiomatic snake_case accessor (`is_one_time_use`, `default_lead_time`, `vendor_account_number`, ...), mapped to Intacct's exact camelCase JSON key when `Vendor` builds the request — see `IntacctRest::Configuration::DEFAULT_VENDOR_WRITABLE_ATTRIBUTES` for the full name mapping (the single source of truth both classes read from). Nested objects (`bank_files`, `contacts`, `term`, `bill_payment`, ...) are **not** individually modeled — pass them as raw Hashes using Intacct's native (camelCase) nested key names, as shown for `term` above.

`IntacctRest::Vendor.call` accepts either attributes (as shown above, or as a single positional Hash) or an already-built `Model::Vendor` instance:

```ruby
model = IntacctRest::Model::Vendor.new(id: "V-00014", name: "NCS, Inc.")
IntacctRest::Vendor.call(model)
```

You can also build the outgoing JSON payload without sending anything, e.g. for debugging:

```ruby
IntacctRest::Vendor.payload(model).to_json # => {"id":"V-00014","name":"NCS, Inc."}
```

### Validation

`IntacctRest::Model::Vendor` declares its validations with a small DSL (`IntacctRest::Model::Base`, shared by any future model) — each declaration is `validate :kind, *options, [:attr, ...]`:

```ruby
validate :presence, %i[id name]
validate :kind_of, :string, %i[id name tax_id ...]
validate :inclusion, BANK_FILE_COUNTRY_CODES, %i[bank_files_payment_country_code]
```

Three validator kinds ship in `IntacctRest::Validators`:

- `:presence` — the attribute must not be `nil`
- `:kind_of` — the attribute, if present, must be one of a small set of types (`:string`, `:integer`, `:numeric`, `:float`, `:boolean`, `:hash`, `:array`, `:date`, `:time`)
- `:inclusion` — the attribute, if present, must be included in a given list (e.g. Intacct's documented bank-file country codes)

By default, `IntacctRest::Vendor.call` validates the model first, raising `IntacctRest::ValidationError` and skipping the HTTP request entirely if it's invalid — currently that means `id`/`name` presence, every field's documented type, and `bank_files["paymentCountryCode"]` (if set) matching a real country code. Note Intacct can auto-generate `id` when document sequencing is enabled for your company; override `valid?`/`errors` in a `Model::Vendor` subclass if you need to relax that.

### Custom fields

Pass a `custom_fields:` Hash — its entries are merged flat into the request payload alongside the standard fields, using whatever field names your Intacct company has configured:

```ruby
IntacctRest::Vendor.call(
  id: "V-00014",
  name: "NCS, Inc.",
  custom_fields: { "preferredCourier__c" => "UPS" }
)
```

### Subclassing for extra validation

Subclass `IntacctRest::Model::Vendor` (not `IntacctRest::Vendor`) and add your own `validate` declarations — they accumulate on top of the built-in ones:

```ruby
class StrictVendor < IntacctRest::Model::Vendor
  validate :presence, %i[tax_id]
end

IntacctRest::Vendor.call(StrictVendor.new(id: "V-00014", name: "NCS, Inc."))
# => raises IntacctRest::ValidationError ("tax_id is required"), no request sent
```

## Errors

All errors inherit from `IntacctRest::Error`:

- `IntacctRest::AuthenticationError` — token request failed, or a request 401'd even after a token refresh
- `IntacctRest::ApiError` — non-2xx response or an `ia::error` payload (`#http_status`, `#body`)
- `IntacctRest::ResponseParseError` — response body wasn't valid JSON (`#raw_body`)
- `IntacctRest::ValidationError` — `Vendor.call` failed client-side validation before any request was sent (`#attributes`)
- `IntacctRest::TooManyPagesError` — `each_page` exceeded `max_pages` (`#pages_fetched`)

## Development

```ruby
bundle install
rake test
```
