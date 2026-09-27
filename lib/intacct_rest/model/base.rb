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
        #
        # on: an optional operation context (:create, :update, ...). A
        # validation declared with on: only runs when #errors/#valid? is
        # called with that same context; without on: it always runs.
        def validate(kind, *args, on: nil)
          attributes = Array(args.pop)
          validators << { kind: kind, attributes: attributes, options: args, on: on }
        end

        def validators
          @validators ||= superclass.respond_to?(:validators) ? superclass.validators.dup : []
        end
      end

      def errors(context = nil)
        self.class.validators.flat_map do |spec|
          next [] unless spec[:on].nil? || spec[:on] == context

          validator = IntacctRest::Validators.fetch(spec[:kind])
          spec[:attributes].flat_map { |attribute| validator.call(self, attribute, *spec[:options]) }
        end
      end

      def valid?(context = nil)
        errors(context).empty?
      end
    end
  end
end
