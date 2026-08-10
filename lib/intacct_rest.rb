# frozen_string_literal: true

require "net/http"
require "json"
require "yaml"
require "pathname"

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

