# frozen_string_literal: true

module IntacctRest
  module Result
    class Base
      attr_reader :model, :code, :body, :headers
      alias response body

      def initialize(model:, code:, body:, headers: {})
        @model = model
        @code = code
        @body = body
        @headers = headers
      end
    end
  end
end
