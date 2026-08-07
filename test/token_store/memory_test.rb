require 'test_helper'

class TestTokenStoreMemory < Minitest::Test
  def setup
    @store = IntacctRest::TokenStore::Memory.new
  end

  def test_read_missing_key
    assert_nil @store.read('missing')
  end

  def test_write_and_read
    @store.write('token', 'abc123')
    assert_equal 'abc123', @store.read('token')
  end

  def test_delete
    @store.write('token', 'abc123')
    @store.delete('token')
    assert_nil @store.read('token')
  end

  def test_ttl_expiry
    @store.write('token', 'abc123', ttl: -1) # already expired
    assert_nil @store.read('token')
  end

  def test_positive_ttl_is_still_readable
    @store.write('token', 'abc123', ttl: 3600)
    assert_equal 'abc123', @store.read('token')
  end
end
