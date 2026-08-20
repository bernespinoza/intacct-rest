require 'test_helper'

class TestModelContact < Minitest::Test
  Source = Struct.new(:id, :show_in_contact_list)

  def test_writable_attributes_are_accessible
    contact = IntacctRest::Model::Contact.new(id: 'C-001', show_in_contact_list: true)

    assert_equal 'C-001', contact.id
    assert_equal true, contact.show_in_contact_list
  end

  def test_valid_with_id
    assert IntacctRest::Model::Contact.new(id: 'C-001').valid?
  end

  def test_invalid_without_id
    contact = IntacctRest::Model::Contact.new

    refute contact.valid?
    assert_includes contact.errors, 'id is required'
  end

  def test_invalid_with_wrong_kind_of_attribute
    contact = IntacctRest::Model::Contact.new(id: 'C-001', show_in_contact_list: 'not-a-boolean')

    refute contact.valid?
    assert_includes contact.errors, 'show_in_contact_list must be a boolean'
  end

  def test_invalid_with_tax_not_a_hash
    contact = IntacctRest::Model::Contact.new(id: 'C-001', tax: 'not-a-hash')

    refute contact.valid?
    assert_includes contact.errors, 'tax must be a hash'
  end

  def test_payload_uses_camel_case_json_keys
    contact = IntacctRest::Model::Contact.new(
      id: 'C-001', show_in_contact_list: true,
      electronic_invoice_details: { 'email' => 'ap@example.com' }
    )

    assert_equal(
      {
        'id' => 'C-001', 'showInContactList' => true,
        'electronicInvoiceDetails' => { 'email' => 'ap@example.com' }
      },
      contact.payload
    )
  end

  def test_new_from_an_arbitrary_source_object
    contact = IntacctRest::Model::Contact.new(Source.new('C-001', true))

    assert_equal 'C-001', contact.id
    assert_equal true, contact.show_in_contact_list
  end

  def test_explicit_keyword_attributes_win_over_source
    contact = IntacctRest::Model::Contact.new(Source.new('C-001', true), show_in_contact_list: false)

    assert_equal 'C-001', contact.id
    assert_equal false, contact.show_in_contact_list
  end
end
