# frozen_string_literal: true

module IntacctRest
  module Validators
    module Inclusion
      def self.call(record, attribute, list)
        value = record.public_send(attribute)
        return [] if value.nil? || Array(list).include?(value)

        ["#{attribute} must be one of #{Array(list).join(', ')} or nil"]
      end
    end

    register(:inclusion, Inclusion)
  end
end
