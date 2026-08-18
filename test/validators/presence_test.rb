require 'test_helper'

class TestValidatorsPresence < Minitest::Test
  Record = Struct.new(:name)

  def test_returns_error_when_nil
    assert_equal ['name is required'], IntacctRest::Validators::Presence.call(Record.new(nil), :name)
  end

  def test_returns_no_errors_when_present
    assert_equal [], IntacctRest::Validators::Presence.call(Record.new('Acme'), :name)
  end

  def test_ignores_extra_options
    assert_equal [], IntacctRest::Validators::Presence.call(Record.new('Acme'), :name, :ignored)
  end
end
