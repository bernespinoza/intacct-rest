require 'test_helper'

class TestValidators < Minitest::Test
  def test_fetch_returns_registered_validator
    assert_equal IntacctRest::Validators::Presence, IntacctRest::Validators.fetch(:presence)
    assert_equal IntacctRest::Validators::KindOf, IntacctRest::Validators.fetch(:kind_of)
    assert_equal IntacctRest::Validators::Inclusion, IntacctRest::Validators.fetch(:inclusion)
  end

  def test_fetch_raises_on_unknown_kind_and_lists_known_kinds
    error = assert_raises(ArgumentError) { IntacctRest::Validators.fetch(:nope) }

    assert_includes error.message, 'nope'
    assert_includes error.message, 'presence'
    assert_includes error.message, 'kind_of'
    assert_includes error.message, 'inclusion'
  end

  def test_each_validator_yields_every_registered_kind
    seen = {}
    IntacctRest::Validators.each_validator { |kind, validator| seen[kind] = validator }

    assert_equal IntacctRest::Validators::Presence, seen[:presence]
    assert_equal IntacctRest::Validators::KindOf, seen[:kind_of]
    assert_equal IntacctRest::Validators::Inclusion, seen[:inclusion]
  end
end
