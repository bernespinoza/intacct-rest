require 'test_helper'

class TestModelTerm < Minitest::Test
  def test_writable_attributes_are_accessible
    term = IntacctRest::Model::Term.new(id: '2-10 Net 30', description: 'N30 with discount')

    assert_equal '2-10 Net 30', term.id
    assert_equal 'N30 with discount', term.description
  end

  def test_custom_fields_defaults_to_empty_array
    term = IntacctRest::Model::Term.new(id: '2-10 Net 30', description: 'N30 with discount')
    assert_equal([], term.custom_fields)
  end

  def test_intacct_object
    assert_equal '/objects/accounts-receivable/term', IntacctRest::Model::Term.new.intacct_object
  end

  def test_valid_with_id_and_description
    assert IntacctRest::Model::Term.new(id: '2-10 Net 30', description: 'N30 with discount').valid?
  end

  def test_invalid_without_id
    term = IntacctRest::Model::Term.new(description: 'N30 with discount')

    refute term.valid?
    assert_includes term.errors, 'id is required'
  end

  def test_invalid_without_description
    term = IntacctRest::Model::Term.new(id: '2-10 Net 30')

    refute term.valid?
    assert_includes term.errors, 'description is required'
  end

  def test_invalid_with_wrong_kind_of_attribute
    term = IntacctRest::Model::Term.new(id: '2-10 Net 30', description: 'N30', due: 'not-a-hash')

    refute term.valid?
    assert_includes term.errors, 'due must be a hash'
  end

  def test_payload_uses_camel_case_json_keys_and_passes_due_through
    term = IntacctRest::Model::Term.new(
      id: '2-10 Net 30', description: 'N30 with discount',
      due: { 'days' => 30, 'from' => 'fromInvoiceDate' }
    )

    assert_equal(
      {
        'id' => '2-10 Net 30', 'description' => 'N30 with discount',
        'due' => { 'days' => 30, 'from' => 'fromInvoiceDate' }
      },
      term.payload
    )
  end

  def test_apply_result_sets_key_href_and_backfills_id
    term = IntacctRest::Model::Term.new(description: 'N30 with discount')
    success = IntacctRest::Result::Success.new(
      model: term, code: '201',
      body: { 'ia::result' => { 'key' => '18', 'href' => '/objects/accounts-receivable/term/18', 'id' => '2-10 Net 30' } }
    )

    term.apply_result(success)

    assert_equal '18', term.key
    assert_equal '/objects/accounts-receivable/term/18', term.href
    assert_equal '2-10 Net 30', term.id
  end
end
