# frozen_string_literal: true

module IntacctRest
  module Model
    # Shared by any IntacctRest::Model class: a small `validate` macro plus
    # #errors/#valid?. Not tied to Vendor specifically — Customer, Bill,
    # etc. can reuse this the same way.
    #
    #   class Thing < IntacctRest::Model::Base
    #     attr_accessor :name
    #     validate :presence, [:name]
    #   end
    class Base
      class << self
        # kind: a key registered in IntacctRest::Validators (:presence,
        # :kind_of, :inclusion, ...). Trailing positional args before the
        # final Array of attribute names are passed through to that
        # validator (e.g. the type symbol for :kind_of, the list for
        # :inclusion).
        def validate(kind, *args)
          attributes = Array(args.pop)
          validators << { kind: kind, attributes: attributes, options: args }
        end

        def validators
          @validators ||= superclass.respond_to?(:validators) ? superclass.validators.dup : []
        end
      end

      def errors
        self.class.validators.flat_map do |spec|
          validator = IntacctRest::Validators.fetch(spec[:kind])
          spec[:attributes].flat_map { |attribute| validator.call(self, attribute, *spec[:options]) }
        end
      end

      def valid?
        errors.empty?
      end
    end
  end
end
