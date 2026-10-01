# frozen_string_literal: true

module IntacctRest
  # Lets Configuration#on_error see an error right before the gem raises it.
  # Used only where an error originates (a failed request, an unparseable
  # response, an unreadable schema file), so each error reaches the hook once.
  #
  # Including classes must expose a private `config` reader (same implicit
  # contract as AuthenticatedRequest).
  module ErrorReporting
    private

    # Raises error exactly as `raise error` would at the call site (same
    # class, message, backtrace and cause), after passing it to on_error
    # with context: — a Hash of safe scalars, never credentials or bodies.
    def raise_reported(error, **context)
      error.set_backtrace(caller) unless error.backtrace
      raise error
    rescue IntacctRest::Error
      begin
        config.on_error&.call(error, context: context)
      rescue StandardError
        nil # a failing hook must never replace the error the caller gets
      end
      raise
    end
  end
end
