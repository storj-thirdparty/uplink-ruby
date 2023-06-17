# frozen_string_literal: true

module Uplink
  class ErrorUtil
    class << self
      def handle_result_error(result)
        handle_error(result[:error])
      end

      def handle_error(error)
        return 0 if error.null?

        error_code = error[:code]
        return error_code if error_code == EOF

        err = CODE_TO_ERROR_MAPPING[error_code]
        raise err.new(error_code, error[:message]) if err

        raise InternalError.new(error_code, error[:message])
      end
    end
  end
end
