require 'test_helper'
require 'tmpdir'

class TestSchemaSource < Minitest::Test
  def test_hash_source_with_string_keys
    source = IntacctRest::SchemaSource.new({ 'invoices' => %w[key state] })
    assert_equal %w[key state], source.for(:invoices)
  end

  def test_hash_source_with_symbol_keys
    source = IntacctRest::SchemaSource.new({ invoices: %w[key state] })
    assert_equal %w[key state], source.for(:invoices)
  end

  def test_for_accepts_string_resource_type
    source = IntacctRest::SchemaSource.new({ 'invoices' => %w[key state] })
    assert_equal %w[key state], source.for('invoices')
  end

  def test_missing_resource_type_returns_empty_array
    source = IntacctRest::SchemaSource.new({ 'invoices' => %w[key state] })
    assert_equal [], source.for(:payments)
  end

  def test_nil_source_returns_empty_array
    source = IntacctRest::SchemaSource.new(nil)
    assert_equal [], source.for(:invoices)
  end

  def test_yaml_string_path
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'schema.yml')
      File.write(path, { 'invoices' => %w[key state] }.to_yaml)

      source = IntacctRest::SchemaSource.new(path)
      assert_equal %w[key state], source.for(:invoices)
    end
  end

  def test_yaml_pathname
    Dir.mktmpdir do |dir|
      path = Pathname.new(File.join(dir, 'schema.yml'))
      path.write({ 'payments' => %w[key amount] }.to_yaml)

      source = IntacctRest::SchemaSource.new(path)
      assert_equal %w[key amount], source.for(:payments)
    end
  end

  def test_missing_file_raises_schema_load_error
    source = IntacctRest::SchemaSource.new('/nonexistent/path/schema.yml')
    assert_raises(IntacctRest::SchemaLoadError) { source.for(:invoices) }
  end

  def test_malformed_yaml_raises_schema_load_error
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'schema.yml')
      File.write(path, "invoices: [key, state\n")

      source = IntacctRest::SchemaSource.new(path)
      assert_raises(IntacctRest::SchemaLoadError) { source.for(:invoices) }
    end
  end

  def test_unsupported_source_type_raises_argument_error
    source = IntacctRest::SchemaSource.new(42)
    assert_raises(ArgumentError) { source.for(:invoices) }
  end

  def test_on_error_receives_schema_load_error_for_a_missing_file
    calls = []
    config = IntacctRest::Configuration.new
    config.on_error = ->(error, context:) { calls << [error, context] }
    source = IntacctRest::SchemaSource.new('/nonexistent/path/schema.yml', config: config)

    error = assert_raises(IntacctRest::SchemaLoadError) { source.for(:invoices) }

    assert_equal [[error, { operation: :schema_load, path: '/nonexistent/path/schema.yml' }]], calls
  end

  def test_on_error_receives_schema_load_error_for_malformed_yaml
    calls = []
    config = IntacctRest::Configuration.new
    config.on_error = ->(error, context:) { calls << [error.class, context] }

    Dir.mktmpdir do |dir|
      path = File.join(dir, 'schema.yml')
      File.write(path, "invoices: [key, state\n")

      source = IntacctRest::SchemaSource.new(path, config: config)
      assert_raises(IntacctRest::SchemaLoadError) { source.for(:invoices) }

      assert_equal [[IntacctRest::SchemaLoadError, { operation: :schema_load, path: path }]], calls
    end
  end

  def test_reports_through_the_global_configuration_without_config_keyword
    calls = []
    IntacctRest.configuration.on_error = ->(error, context:) { calls << error.class }
    source = IntacctRest::SchemaSource.new('/nonexistent/path/schema.yml')

    assert_raises(IntacctRest::SchemaLoadError) { source.for(:invoices) }

    assert_equal [IntacctRest::SchemaLoadError], calls
  ensure
    IntacctRest.reset
  end
end
