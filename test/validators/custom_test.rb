require 'test_helper'

class TestValidatorsCustom < Minitest::Test
  class Record
    attr_accessor :value

    def initialize(value)
      @value = value
    end

    def even?(value)
      value.even?
    end
  end

  def test_returns_no_errors_when_nil
    assert_equal [], IntacctRest::Validators::Custom.call(Record.new(nil), :value, :even?)
  end

  def test_returns_no_errors_when_method_returns_truthy
    assert_equal [], IntacctRest::Validators::Custom.call(Record.new(2), :value, :even?)
  end

  def test_returns_error_when_method_returns_falsy
    assert_equal ['value is invalid'], IntacctRest::Validators::Custom.call(Record.new(3), :value, :even?)
  end

  def test_registered_in_the_registry
    assert_equal IntacctRest::Validators::Custom, IntacctRest::Validators.fetch(:custom)
  end
end
