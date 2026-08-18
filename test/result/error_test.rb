require 'test_helper'

class TestResultError < Minitest::Test
  def build(body)
    IntacctRest::Result::Error.new(model: :a_model, code: '400', body: body)
  end

  def test_success_and_failed
    result = build({})

    refute result.success?
    assert result.failed?
  end

  def test_error_reads_nested_ia_error
    result = build({ 'ia::result' => { 'ia::error' => { 'message' => 'bad request' } } })

    assert_equal({ 'message' => 'bad request' }, result.error)
  end

  def test_error_falls_back_to_top_level_ia_error
    result = build({ 'ia::error' => { 'message' => 'boom' } })

    assert_equal({ 'message' => 'boom' }, result.error)
  end

  def test_headers_defaults_to_empty_hash
    assert_equal({}, build({}).headers)
  end
end
