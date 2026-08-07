require 'test_helper'

class TestFilter < Minitest::Test
  def test_eq
    assert_equal({ '$eq' => { 'state' => 'paid' } }, IntacctRest::Filter.eq('state', 'paid'))
  end

  def test_not_eq
    assert_equal({ '$ne' => { 'state' => 'paid' } }, IntacctRest::Filter.not_eq('state', 'paid'))
  end

  def test_gt
    assert_equal({ '$gt' => { 'audit.modifiedDateTime' => '2025-01-01' } },
                 IntacctRest::Filter.gt('audit.modifiedDateTime', '2025-01-01'))
  end

  def test_gte
    assert_equal({ '$gte' => { 'total' => 0 } }, IntacctRest::Filter.gte('total', 0))
  end

  def test_lt
    assert_equal({ '$lt' => { 'total' => 100 } }, IntacctRest::Filter.lt('total', 100))
  end

  def test_lte
    assert_equal({ '$lte' => { 'total' => 100 } }, IntacctRest::Filter.lte('total', 100))
  end

  def test_and_flattens_fragments
    a = IntacctRest::Filter.eq('state', 'paid')
    b = IntacctRest::Filter.gt('total', 0)
    assert_equal [a, b], IntacctRest::Filter.and(a, b)
  end

  def test_field_is_stringified
    assert_equal({ '$eq' => { 'state' => 'paid' } }, IntacctRest::Filter.eq(:state, 'paid'))
  end
end
