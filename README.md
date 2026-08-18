# IntacctRest

A small, framework-agnostic Ruby client for [Sage Intacct's REST API v1](https://developer.sage.com/intacct/docs/1/sage-intacct-rest-api). It wraps:

- **OAuth2 token handling** (`client_credentials` and `refresh_token` grants), with pluggable token storage
- **The `POST /services/core/query` endpoint**, for any Intacct object (invoices, bills, customers, ...), with pagination and a small filter-operator builder
- **The `POST /objects/accounts-payable/vendor` endpoint**, via `IntacctRest::Endpoints::CreateVendor` (the use case), `IntacctRest::Post` (the generic, reusable "send this model" operation), and `IntacctRest::Model::Vendor` (the data + a small declarative validation DSL), covering every vendor field plus custom fields

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

Three pieces work together, each with one job:

- **`IntacctRest::Model::Vendor`** — the vendor's data and validations. No config, no token provider, no HTTP knowledge. Build one, inspect it, `valid?`/`errors` it, all without touching the network.
- **`IntacctRest::Post`** — a generic "send this model" operation. Works against *any* model that responds to `#intacct_object` (the endpoint path), `#payload` (the outgoing JSON), and `#valid?`/`#errors` — not specific to vendors.
- **`IntacctRest::Endpoints::CreateVendor`** — the vendor-specific use case: calls `Post`, then checks the response actually contains the fields you expect.

```ruby
vendor = IntacctRest::Model::Vendor.new(
  id:           "V-00014",
  name:         "NCS, Inc.",
  credit_limit: 40_000,
  is_on_hold:   false,
  term:         { "id" => "Net 30" }
)

result = IntacctRest::Endpoints::CreateVendor.call(vendor: vendor, results: %i[id key href])

result.success? # => true
vendor.key      # => "111"       (written onto the model by Post, via model.apply_result)
vendor.href     # => "/objects/accounts-payable/vendor/111"
```

`IntacctRest::Model::Vendor` exposes every field from Sage Intacct's vendor object as a Ruby-idiomatic snake_case accessor (`is_one_time_use`, `default_lead_time`, `vendor_account_number`, ...), mapped to Intacct's exact camelCase JSON key when `#payload` builds the request — see `IntacctRest::Configuration::DEFAULT_VENDOR_WRITABLE_ATTRIBUTES` for the full name mapping. Nested objects (`bank_files`, `contacts`, `term`, `bill_payment`, ...) are **not** individually modeled — pass them as raw Hashes using Intacct's native (camelCase) nested key names, as shown for `term` above.

You can also build the outgoing JSON payload without sending anything, e.g. for debugging:

```ruby
vendor.payload.to_json # => {"id":"V-00014","name":"NCS, Inc."}
```

### Building a model from an existing object

`Model::Vendor.new` also accepts a single positional "source" object — an ActiveRecord record, an `OpenStruct`, another `Model::Vendor` — and pulls any matching attribute off it via duck-typing (`source.respond_to?(attr)`). Explicit keyword attributes always win over whatever the source provided:

```ruby
vendor = IntacctRest::Model::Vendor.new(some_ar_vendor, credit_limit: 1_000) # override just one field
```

### The Result

`IntacctRest::Post` (and therefore `Endpoints::CreateVendor`) never raises for the HTTP outcome itself — it always returns an `IntacctRest::Result` (`Result::Success` or `Result::Error`), each responding to `#code`, `#body`, `#response` (alias for `#body`), `#headers`, `#model`, and `#success?`/`#failed?`:

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

- `IntacctRest::ValidationError` — the model is invalid (see Validation, below)
- `IntacctRest::AuthenticationError` — a request 401'd even after a token refresh
- `IntacctRest::ResponseParseError` — the response body wasn't valid JSON
- `IntacctRest::ApiError` (from `Endpoints::CreateVendor` specifically) — a *successful* response was missing one of the fields declared in `results:`

### Validation

`IntacctRest::Model::Vendor` declares its validations with a small DSL (`IntacctRest::Model::Base`, shared by any future model) — each declaration is `validate :kind, *options, [:attr, ...]`:

```ruby
validate :presence, %i[id name]
validate :kind_of, :string, %i[id name tax_id ...]
validate :inclusion, BANK_FILE_COUNTRY_CODES, %i[bank_files_payment_country_code]
validate :custom, :valid_date, %i[last_payment_made_date]
```

Four validator kinds ship in `IntacctRest::Validators`:

- `:presence` — the attribute must not be `nil`
- `:kind_of` — the attribute, if present, must be one of a small set of types (`:string`, `:integer`, `:numeric`, `:float`, `:boolean`, `:hash`, `:array`, `:date`, `:time`)
- `:inclusion` — the attribute, if present, must be included in a given list (e.g. Intacct's documented bank-file country codes)
- `:custom` — the attribute, if present, is passed to an instance method you name (`record.send(method_name, value)`); a falsy return means invalid

By default, `Post` validates the model first, raising `IntacctRest::ValidationError` and skipping the HTTP request entirely if it's invalid — currently that means `id`/`name` presence, every field's documented type, and `bank_files["paymentCountryCode"]` (if set) matching a real country code. Note Intacct can auto-generate `id` when document sequencing is enabled for your company; override `valid?`/`errors` in a `Model::Vendor` subclass if you need to relax that.

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

## Errors

All exceptions inherit from `IntacctRest::Error`:

- `IntacctRest::AuthenticationError` — token request failed, or a request 401'd even after a token refresh
- `IntacctRest::ApiError` — `Query`: non-2xx response or an `ia::error` payload (`#http_status`, `#body`). `Endpoints::CreateVendor`: a successful response was missing a field declared in `results:`
- `IntacctRest::ResponseParseError` — response body wasn't valid JSON (`#raw_body`)
- `IntacctRest::ValidationError` — a model failed validation before any request was sent (`#attributes`)
- `IntacctRest::TooManyPagesError` — `each_page` exceeded `max_pages` (`#pages_fetched`)

Non-2xx responses from `IntacctRest::Post`/`Endpoints::CreateVendor` are **not** exceptions — see The Result, above.

## Development

```ruby
bundle install
rake test
```
