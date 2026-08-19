# frozen_string_literal: true

require "net/http"
require "json"
require "yaml"
require "pathname"
require "date"

module IntacctRest
  API_URI = 'https://api.intacct.com/ia/api'
  API_VERSION = 'v1'
end

require 'intacct_rest/version'
require 'intacct_rest/errors'
require 'intacct_rest/token_store/memory'
require 'intacct_rest/configuration'
require 'intacct_rest/client'
require 'intacct_rest/filter'
require 'intacct_rest/page'
require 'intacct_rest/authenticated_request'
require 'intacct_rest/oauth_client'
require 'intacct_rest/custom_field'
require 'intacct_rest/validators'
require 'intacct_rest/validators/presence'
require 'intacct_rest/validators/kind_of'
require 'intacct_rest/validators/inclusion'
require 'intacct_rest/validators/custom'
require 'intacct_rest/model/base'
require 'intacct_rest/model/vendor'
require 'intacct_rest/model/invoice'
require 'intacct_rest/model/term'
require 'intacct_rest/model/invoice_line'
require 'intacct_rest/model/currency'
require 'intacct_rest/model/customer'
require 'intacct_rest/model/contact'
require 'intacct_rest/result/base'
require 'intacct_rest/result/success'
require 'intacct_rest/result/error'
require 'intacct_rest/post'
require 'intacct_rest/endpoints/create_vendor'
require 'intacct_rest/endpoints/create_invoice'
require 'intacct_rest/endpoints/create_term'
require 'intacct_rest/endpoints/create_invoice_line'
require 'intacct_rest/endpoints/create_customer'
require 'intacct_rest/query'
require 'intacct_rest/objects'
require 'intacct_rest/schema_generator'
require 'intacct_rest/schema_source'

module IntacctRest
  class << self
    attr_writer :configuration
  end

  def self.reset
    @configuration = nil
  end

  def self.configuration
    @configuration ||= IntacctRest::Configuration.new
  end

  def self.configure
    yield configuration if block_given?
  end
end

