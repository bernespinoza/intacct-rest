# frozen_string_literal: true

module IntacctRest
  class CustomField
    DEFAULT_NAMESPACE = 'nsp'

    attr_accessor :namespace, :name, :value

    def initialize(name:, value: nil, namespace: DEFAULT_NAMESPACE)
      @namespace = namespace
      @name = name
      @value = value
    end

    def key
      "#{namespace}::#{name}"
    end
  end
end
