# frozen_string_literal: true

module IntacctRest
  module Validators
    module Custom
      def self.call(record, attribute, method_name)
        value = record.public_send(attribute)
        return [] if value.nil?
        return [] if record.send(method_name, value)

        ["#{attribute} is invalid"]
      end
    end

    register(:custom, Custom)
  end
end
