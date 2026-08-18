require 'test_helper'

class TestCustomField < Minitest::Test
  def test_key_defaults_to_nsp_namespace
    field = IntacctRest::CustomField.new(name: 'preferredCourier', value: 'UPS')

    assert_equal 'nsp', field.namespace
    assert_equal 'nsp::preferredCourier', field.key
  end

  def test_key_with_explicit_namespace
    field = IntacctRest::CustomField.new(name: 'preferredCourier', value: 'UPS', namespace: 'acme')

    assert_equal 'acme::preferredCourier', field.key
  end

  def test_accessors_are_settable
    field = IntacctRest::CustomField.new(name: 'a', value: 1)
    field.name = 'b'
    field.value = 2
    field.namespace = 'c'

    assert_equal 'b', field.name
    assert_equal 2, field.value
    assert_equal 'c::b', field.key
  end
end
