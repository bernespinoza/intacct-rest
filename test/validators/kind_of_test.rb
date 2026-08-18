require 'test_helper'

class TestValidatorsKindOf < Minitest::Test
  Record = Struct.new(:value)

  def test_returns_no_errors_when_nil
    assert_equal [], IntacctRest::Validators::KindOf.call(Record.new(nil), :value, :string)
  end

  def test_string
    assert_equal [], IntacctRest::Validators::KindOf.call(Record.new('a'), :value, :string)
    assert_equal ['value must be a string'], IntacctRest::Validators::KindOf.call(Record.new(1), :value, :string)
  end

  def test_integer
    assert_equal [], IntacctRest::Validators::KindOf.call(Record.new(1), :value, :integer)
    assert_equal ['value must be a integer'], IntacctRest::Validators::KindOf.call(Record.new(1.5), :value, :integer)
  end

  def test_numeric_accepts_integer_and_float
    assert_equal [], IntacctRest::Validators::KindOf.call(Record.new(1), :value, :numeric)
    assert_equal [], IntacctRest::Validators::KindOf.call(Record.new(1.5), :value, :numeric)
    assert_equal ['value must be a numeric'], IntacctRest::Validators::KindOf.call(Record.new('1'), :value, :numeric)
  end

  def test_float
    assert_equal [], IntacctRest::Validators::KindOf.call(Record.new(1.5), :value, :float)
    assert_equal ['value must be a float'], IntacctRest::Validators::KindOf.call(Record.new(1), :value, :float)
  end

  def test_boolean_accepts_true_and_false
    assert_equal [], IntacctRest::Validators::KindOf.call(Record.new(true), :value, :boolean)
    assert_equal [], IntacctRest::Validators::KindOf.call(Record.new(false), :value, :boolean)
    assert_equal ['value must be a boolean'], IntacctRest::Validators::KindOf.call(Record.new('true'), :value, :boolean)
  end

  def test_hash
    assert_equal [], IntacctRest::Validators::KindOf.call(Record.new({}), :value, :hash)
    assert_equal ['value must be a hash'], IntacctRest::Validators::KindOf.call(Record.new([]), :value, :hash)
  end

  def test_array
    assert_equal [], IntacctRest::Validators::KindOf.call(Record.new([]), :value, :array)
    assert_equal ['value must be a array'], IntacctRest::Validators::KindOf.call(Record.new({}), :value, :array)
  end

  def test_date
    assert_equal [], IntacctRest::Validators::KindOf.call(Record.new(Date.today), :value, :date)
    assert_equal ['value must be a date'], IntacctRest::Validators::KindOf.call(Record.new('2026-01-01'), :value, :date)
  end

  def test_time
    assert_equal [], IntacctRest::Validators::KindOf.call(Record.new(Time.now), :value, :time)
    assert_equal ['value must be a time'], IntacctRest::Validators::KindOf.call(Record.new('now'), :value, :time)
  end

  def test_raises_on_unknown_kind
    assert_raises(ArgumentError) { IntacctRest::Validators::KindOf.call(Record.new('a'), :value, :nope) }
  end
end
