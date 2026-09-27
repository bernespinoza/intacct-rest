require 'test_helper'

class TestModelBase < Minitest::Test
  Thing = Class.new(IntacctRest::Model::Base) do
    attr_accessor :name, :key

    validate :kind_of, :string, %i[name]
    validate :presence, %i[name], on: :create
    validate :presence, %i[key], on: :update
  end

  def test_validations_without_context_always_run
    thing = Thing.new.tap { |t| t.name = 1 }

    assert_includes thing.errors, 'name must be a string'
    assert_includes thing.errors(:create), 'name must be a string'
    assert_includes thing.errors(:update), 'name must be a string'
  end

  def test_contextual_validations_only_run_for_their_context
    thing = Thing.new

    assert_equal ['name is required'], thing.errors(:create)
    assert_equal ['key is required'], thing.errors(:update)
    assert_empty thing.errors
  end

  def test_valid_accepts_a_context
    thing = Thing.new.tap { |t| t.key = '111' }

    assert thing.valid?(:update)
    refute thing.valid?(:create)
    assert thing.valid?
  end

  def test_subclass_inherits_contextual_validations
    subclass = Class.new(Thing) { validate :presence, %i[name], on: :update }

    assert_equal ['key is required', 'name is required'], subclass.new.errors(:update)
  end
end
