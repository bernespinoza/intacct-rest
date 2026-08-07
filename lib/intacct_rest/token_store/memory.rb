# frozen_string_literal: true

module IntacctRest
  module TokenStore
    # Default token store: thread-safe, self-expiring, process-local.
    # Any object responding to #read/#write(ttl:)/#delete can be used instead
    # (see IntacctRest::Configuration#token_store) — e.g. a Redis-backed store.
    class Memory
      def initialize
        @values = {}
        @mutex = Mutex.new
      end

      def read(key)
        @mutex.synchronize do
          value, expires_at = @values[key]
          next nil if value.nil?
          next nil if expires_at && expires_at <= Time.now

          value
        end
      end

      def write(key, value, ttl: nil)
        @mutex.synchronize do
          expires_at = ttl ? Time.now + ttl : nil
          @values[key] = [value, expires_at]
        end
      end

      def delete(key)
        @mutex.synchronize { @values.delete(key) }
      end
    end
  end
end
