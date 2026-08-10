module IntacctRest
  class Configuration
    DEFAULT_BASE_URL       = "#{IntacctRest::API_URI}/#{IntacctRest::API_VERSION}".freeze
    DEFAULT_TOKEN_PATH     = '/oauth2/token'.freeze
    DEFAULT_QUERY_PATH     = '/services/core/query'.freeze
    DEFAULT_PAGE_SIZE      = 200
    DEFAULT_MAX_PAGES      = 50
    DEFAULT_TOKEN_KEY_PREFIX = 'intacct_rest:oauth'.freeze

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
