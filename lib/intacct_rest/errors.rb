# frozen_string_literal: true

module IntacctRest
  class Error < StandardError; end

  class AuthenticationError < Error; end

  class ResponseParseError < Error
    attr_reader :raw_body

    def initialize(message, raw_body: nil)
      super(message)
      @raw_body = raw_body
    end
  end

  class ApiError < Error
    attr_reader :http_status, :body

    def initialize(message, http_status: nil, body: nil)
      super(message)
      @http_status = http_status
      @body = body
    end
  end

  class TooManyPagesError < Error
    attr_reader :pages_fetched

    def initialize(message, pages_fetched:)
      super(message)
      @pages_fetched = pages_fetched
    end
  end
end
