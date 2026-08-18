# frozen_string_literal: true

module IntacctRest
  module Validators
    module Presence
      def self.call(record, attribute, *)
        record.public_send(attribute).nil? ? ["#{attribute} is required"] : []
      end
    end

    register(:presence, Presence)
  end
end
