# IntacctRest

A small, framework-agnostic Ruby client for [Sage Intacct's REST API v1](https://developer.sage.com/intacct/docs/1/sage-intacct-rest-api). It wraps:

- **OAuth2 token handling** (`client_credentials` and `refresh_token` grants), with pluggable token storage
- **The `POST /services/core/query` endpoint**, for any Intacct object (invoices, bills, customers, ...), with pagination and a small filter-operator builder
- **The Objects API** (`GET /objects/{resource}` and `GET /objects/{resource}/{key}`), and a schema generator built on top of it that discovers a resource's fields from a real record

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

## Errors

All errors inherit from `IntacctRest::Error`:

- `IntacctRest::AuthenticationError` — token request failed, or a request 401'd even after a token refresh
- `IntacctRest::ApiError` — non-2xx response or an `ia::error` payload (`#http_status`, `#body`)
- `IntacctRest::ResponseParseError` — response body wasn't valid JSON (`#raw_body`)
- `IntacctRest::TooManyPagesError` — `each_page` exceeded `max_pages` (`#pages_fetched`)
- `IntacctRest::SchemaGenerationError` — `SchemaGenerator` found no records to sample
- `IntacctRest::SchemaLoadError` — `SchemaSource` failed to read/parse a YAML file

## Development

```ruby
bundle install
rake test
```
