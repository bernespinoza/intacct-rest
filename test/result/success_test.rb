require 'test_helper'

class TestResultSuccess < Minitest::Test
  def build(body)
    IntacctRest::Result::Success.new(model: :a_model, code: '201', body: body, headers: { 'x' => ['1'] })
  end

  def test_success_and_failed
    result = build({})

    assert result.success?
    refute result.failed?
  end

  def test_reader_accessors
    result = build({})

    assert_equal :a_model, result.model
    assert_equal '201', result.code
    assert_equal({ 'x' => ['1'] }, result.headers)
  end

  def test_response_is_aliased_to_body
    body = { 'ia::result' => {} }
    result = build(body)

    assert_equal body, result.response
    assert_same result.body, result.response
  end

  def test_result_returns_ia_result
    result = build({ 'ia::result' => { 'key' => '111', 'href' => '/x/111' } })

    assert_equal({ 'key' => '111', 'href' => '/x/111' }, result.result)
  end

  def test_result_defaults_to_empty_hash_when_missing
    result = build({})

    assert_equal({}, result.result)
  end

  def test_dynamic_access_to_result_fields
    result = build({ 'ia::result' => { 'key' => '111', 'href' => '/x/111' } })

    assert_equal '111', result.key
    assert_equal '/x/111', result.href
    assert result.respond_to?(:key)
  end

  def test_dynamic_access_raises_for_unknown_fields
    result = build({ 'ia::result' => { 'key' => '111' } })

    assert_raises(NoMethodError) { result.nope }
    refute result.respond_to?(:nope)
  end
end
