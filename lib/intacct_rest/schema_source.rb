# frozen_string_literal: true

module IntacctRest
  # Resolves Configuration#schema — a Hash, a YAML file path (String or
  # Pathname), or nil — into field arrays for a given resource type.
  #
  #   IntacctRest::SchemaSource.new({invoices: %w[key state]}).for(:invoices)
  #   IntacctRest::SchemaSource.new("config/intacct_schema.yml").for(:invoices)
  class SchemaSource
    def initialize(source)
      @source = source
    end

    def for(resource_type)
      Array(data[resource_type.to_s]).map(&:to_s)
    end

    private

    attr_reader :source

    def data
      @data ||= normalize(source)
    end

    def normalize(source)
      case source
      when Hash
        source.transform_keys(&:to_s)
      when String, Pathname
        load_yaml(source)
      when nil
        {}
      else
        raise ArgumentError, "Unsupported schema source: #{source.class}"
      end
    end

    def load_yaml(path)
      YAML.safe_load_file(path.to_s) || {}
    rescue Errno::ENOENT, Psych::Exception => e
      raise IntacctRest::SchemaLoadError, "Failed to load schema from #{path}: #{e.message}"
    end
  end
end
