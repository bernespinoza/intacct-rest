# frozen_string_literal: true

module IntacctRest
  module Result
    class Error < Base
      def success? = false
      def failed? = true

      def error
        body.dig('ia::result', 'ia::error') || body['ia::error']
      end
    end
  end
end
