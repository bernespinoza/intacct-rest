require 'test_helper'

class TestValidatorsInclusion < Minitest::Test
  Record = Struct.new(:code)

  def test_returns_no_errors_when_nil
    assert_equal [], IntacctRest::Validators::Inclusion.call(Record.new(nil), :code, %w[us gb])
  end

  def test_returns_no_errors_when_included
    assert_equal [], IntacctRest::Validators::Inclusion.call(Record.new('us'), :code, %w[us gb])
  end

  def test_returns_error_when_not_included
    assert_equal(
      ['code must be one of us, gb or nil'],
      IntacctRest::Validators::Inclusion.call(Record.new('zz'), :code, %w[us gb])
    )
  end
end
