# frozen_string_literal: true

module IntacctRest
  Page = Struct.new(:items, :next_cursor, :raw, keyword_init: true)
end
