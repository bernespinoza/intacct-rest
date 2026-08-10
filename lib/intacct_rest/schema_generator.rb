# frozen_string_literal: true

module IntacctRest
  # Discovers a resource's available fields by sampling ONE real record
  # (via Objects#find) and flattening its keys — nested Hashes are
  # dot-joined ("paymentInformation.fullyPaidDate"), nested Arrays are
  # sampled from their first element only ("lines.glAccount").
  #
  # This is a LOWER BOUND, not a guarantee of completeness: any field that
  # is nil/empty on the sampled record won't appear. A nil value at a
  # Hash-typed position (e.g. an unpaid invoice's null `paymentInformation`)
  # collapses that whole subtree to a single bare leaf instead of its
  # nested fields — inherent to single-record sampling. Treat generated
  # output as a starting point to hand-review and merge, not as ground
  # truth to commit blindly.
  class SchemaGenerator
    def initialize(objects: IntacctRest::Objects.new)
      @objects = objects
    end

    # key: overrides the auto-picked sample record — useful when the
    # auto-picked one turns out sparse/partial.
    def generate(resource, key: nil)
      key ||= sample_key(resource)
      flatten(objects.find(resource, key))
    end

    def generate_all(resources)
      resources.transform_values { |resource| generate(resource) }
    end

    # Overwrites path unconditionally — no backup, no merge with any
    # existing content. Review the diff before committing the result.
    def write(path, resources)
      data = generate_all(resources).transform_keys(&:to_s)
      File.write(path, data.to_yaml)
      data
    end

    private

    attr_reader :objects

    # Intacct's /objects/{resource} list endpoint has no documented sort
    # order (unconfirmed against real docs) — this is an arbitrary
    # representative record from the first page, not "the latest."
    def sample_key(resource)
      items = objects.list(resource)
      key = items.last && items.last['key']
      key || raise(IntacctRest::SchemaGenerationError, "No records found for #{resource} to sample a schema from")
    end

    # NOTE: do not add a `return if value.nil?` guard here — a nil leaf
    # value still has a field name (prefix) worth recording; only a Hash
    # or Array value collapses instead of terminating, and only Array
    # samples its first element.
    def flatten(value, prefix = nil, fields = [])
      case value
      when Hash
        value.each { |k, v| flatten(v, [prefix, k].compact.join('.'), fields) }
      when Array
        flatten(value.first, prefix, fields)
      else
        fields << prefix if prefix
      end
      fields
    end
  end
end
