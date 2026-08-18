# frozen_string_literal: true

module IntacctRest
  # Operation object for POST /objects/accounts-payable/vendor. Holds no
  # vendor data itself — see IntacctRest::Model::Vendor for that.
  #
  #   vendor = IntacctRest::Vendor.call(id: "V-00014", name: "NCS, Inc.")
  #   vendor.key  # => "111"
  #
  #   model = IntacctRest::Model::Vendor.new(id: "V-00014", name: "NCS, Inc.")
  #   IntacctRest::Vendor.call(model)
  class Vendor
    include AuthenticatedRequest

    INTACCT_OBJECT = '/objects/accounts-payable/vendor'.freeze
    ATTRIBUTE_MAP = IntacctRest::Configuration::DEFAULT_VENDOR_WRITABLE_ATTRIBUTES

    # Accepts either attributes (kwargs or a positional Hash) or an
    # already-built IntacctRest::Model::Vendor (or subclass), and returns
    # the (now key/href-populated) model either way.
    def self.call(source = nil, config: IntacctRest.configuration, token_provider: nil, **attributes)
      model = source.is_a?(IntacctRest::Model::Vendor) ? source : IntacctRest::Model::Vendor.new(**(source || attributes))
      new(config: config, token_provider: token_provider).call(model)
    end

    # Pure data transform, no auth/network needed — useful to inspect the
    # outgoing JSON without sending it.
    def self.payload(model)
      ATTRIBUTE_MAP.each_with_object({}) do |(attr, json_key), hash|
        value = model.public_send(attr)
        hash[json_key] = value unless value.nil?
      end.merge(model.custom_fields || {})
    end

    def initialize(config: IntacctRest.configuration, token_provider: nil)
      @config = config
      @token_provider = token_provider || IntacctRest::OauthClient.new(config: config)
    end

    def call(model)
      raise IntacctRest::ValidationError.new(model.errors.join('; '), attributes: model.errors) unless model.valid?

      result = authenticated_request(:post, intacct_object, body: self.class.payload(model))['ia::result']
      apply_result(model, result)
      model
    end

    private

    attr_reader :config, :token_provider

    def apply_result(model, result)
      return unless result

      model.key = result['key']
      model.href = result['href']
      model.id = result['id'] if result['id'] && model.id.nil?
    end

    def intacct_object
      INTACCT_OBJECT
    end
  end
end
