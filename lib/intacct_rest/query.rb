# frozen_string_literal: true

module IntacctRest
  # Wraps Intacct's POST /services/core/query endpoint for any object type
  # (not just invoices), with pagination support.
  #
  #   query = IntacctRest::Query.new(
  #     resource: "accounts-receivable/invoice",
  #     schema:   %w[key state],
  #     filters:  [IntacctRest::Filter.eq("state", "paid")]
  #   )
  #   query.each_page { |items, next_cursor| ... }
  class Query
    attr_reader :resource, :schema, :filters, :order_by, :size, :start, :token_provider

    def initialize(resource:, schema: [], filters: [], order_by: nil, size: nil, start: nil,
                   config: IntacctRest.configuration, token_provider: nil)
      @resource = resource
      @schema = schema
      @filters = filters
      @order_by = order_by
      @config = config
      @size = size || config.page_size
      @start = start
      @token_provider = token_provider || IntacctRest::OauthClient.new(config: config)
    end

    def url
      "#{config.base_url}#{config.query_path}"
    end

    def payload
      {
        'object'  => resource,
        'fields'  => schema,
        'filters' => filters,
        'orderBy' => order_by,
        'size'    => size,
        'start'   => start
      }.compact
    end

    def call
      execute(retried: false)
    end

    def each_page(max_pages: config.max_pages)
      cursor = start
      pages_fetched = 0

      loop do
        pages_fetched += 1
        if pages_fetched > max_pages
          raise IntacctRest::TooManyPagesError.new(
            "Exceeded max pages (#{max_pages}) while querying #{resource}",
            pages_fetched: pages_fetched - 1
          )
        end

        page = with_start(cursor).call
        yield page.items, page.next_cursor

        break unless page.next_cursor

        cursor = page.next_cursor
      end
    end

    private

    attr_reader :config

    def with_start(cursor)
      return self if cursor == start

      self.class.new(resource: resource, schema: schema, filters: filters, order_by: order_by,
                      size: size, start: cursor, config: config, token_provider: token_provider)
    end

    def execute(retried:)
      client = IntacctRest::Client.new(url, :post)
      client.add_header('Authorization', "Bearer #{token_provider.access_token}")
      client.body = payload

      response = client.request

      if response.is_a?(Net::HTTPUnauthorized)
        raise IntacctRest::AuthenticationError, 'Authentication failed after token refresh' if retried

        token_provider.refresh_access_token
        return execute(retried: true)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise IntacctRest::ApiError.new("HTTP #{response.code} querying #{resource}",
                                         http_status: response.code, body: response.body)
      end

      parsed = parse(response.body)

      if parsed['ia::error']
        raise IntacctRest::ApiError.new("API error querying #{resource}", http_status: response.code, body: parsed)
      end

      IntacctRest::Page.new(
        items:       parsed['ia::result'] || [],
        next_cursor: parsed.dig('ia::meta', 'next'),
        raw:         parsed
      )
    end

    def parse(body)
      JSON.parse(body)
    rescue JSON::ParserError => e
      raise IntacctRest::ResponseParseError.new(e.message, raw_body: body)
    end
  end
end
