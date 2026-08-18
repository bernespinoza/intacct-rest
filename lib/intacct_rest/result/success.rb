# frozen_string_literal: true

module IntacctRest
  module Result
    class Success < Base
      def success? = true
      def failed? = false

      # The record reference Intacct returns, e.g.
      # {"key"=>"111","href"=>"/objects/accounts-payable/vendor/111"}
      def result
        @result ||= body['ia::result'] || {}
      end

      # "Functional object" access: success.key, success.href, success.id
      def method_missing(name, *args, &block)
        return super unless args.empty? && !block && result.key?(name.to_s)

        result[name.to_s]
      end

      def respond_to_missing?(name, include_private = false)
        result.key?(name.to_s) || super
      end
    end
  end
end
