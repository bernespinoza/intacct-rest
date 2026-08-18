require 'test_helper'
require 'tmpdir'

class FakeObjects
  def initialize(list:, records:)
    @list = list
    @records = records
  end

  def list(_resource)
    @list
  end

  def find(_resource, key)
    @records.fetch(key)
  end
end

class TestSchemaGenerator < Minitest::Test
  def test_generate_flattens_nested_hash
    record = {
      'key' => '1', 'state' => 'paid',
      'paymentInformation' => { 'fullyPaidDate' => '2026-01-01', 'totalBaseAmountPaid' => 100 }
    }
    generator = build_generator(list: [{ 'key' => '1' }], records: { '1' => record })

    fields = generator.generate('accounts-receivable/invoice')

    assert_equal %w[key state paymentInformation.fullyPaidDate paymentInformation.totalBaseAmountPaid], fields
  end

  def test_generate_samples_array_first_element_only
    record = { 'key' => '1', 'lines' => [{ 'glAccount' => '4000' }, { 'glAccount' => '5000' }] }
    generator = build_generator(list: [{ 'key' => '1' }], records: { '1' => record })

    assert_equal %w[key lines.glAccount], generator.generate('accounts-receivable/invoice')
  end

  def test_generate_collapses_nil_hash_to_bare_leaf
    record = { 'key' => '1', 'paymentInformation' => nil }
    generator = build_generator(list: [{ 'key' => '1' }], records: { '1' => record })

    assert_equal %w[key paymentInformation], generator.generate('accounts-receivable/invoice')
  end

  def test_generate_collapses_empty_array_to_bare_leaf
    record = { 'key' => '1', 'lines' => [] }
    generator = build_generator(list: [{ 'key' => '1' }], records: { '1' => record })

    assert_equal %w[key lines], generator.generate('accounts-receivable/invoice')
  end

  def test_generate_uses_explicit_key_override
    record = { 'key' => '99', 'state' => 'paid' }
    generator = build_generator(list: [{ 'key' => '1' }], records: { '99' => record })

    assert_equal %w[key state], generator.generate('accounts-receivable/invoice', key: '99')
  end

  def test_generate_raises_when_list_is_empty
    generator = build_generator(list: [], records: {})

    assert_raises(IntacctRest::SchemaGenerationError) { generator.generate('accounts-receivable/invoice') }
  end

  def test_generate_all_maps_resource_names_to_field_arrays
    record = { 'key' => '1', 'state' => 'paid' }
    generator = build_generator(list: [{ 'key' => '1' }], records: { '1' => record })

    result = generator.generate_all(invoices: 'accounts-receivable/invoice', payments: 'accounts-receivable/payment')

    assert_equal({ invoices: %w[key state], payments: %w[key state] }, result)
  end

  def test_write_dumps_yaml_with_string_keys
    record = { 'key' => '1', 'state' => 'paid' }
    generator = build_generator(list: [{ 'key' => '1' }], records: { '1' => record })

    Dir.mktmpdir do |dir|
      path = File.join(dir, 'schema.yml')
      generator.write(path, invoices: 'accounts-receivable/invoice')

      assert_equal({ 'invoices' => %w[key state] }, YAML.safe_load_file(path))
    end
  end

  private

  def build_generator(list:, records:)
    IntacctRest::SchemaGenerator.new(objects: FakeObjects.new(list: list, records: records))
  end
end
