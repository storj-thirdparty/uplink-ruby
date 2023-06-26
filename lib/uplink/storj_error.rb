# frozen_string_literal: true

module Uplink
  class StorjError < StandardError
    attr_reader :code

    def initialize(code, message)
      super(message)
      @code = code
    end
  end

  class InternalError < StorjError; end
  class CanceledError < StorjError; end
  class InvalidHandleError < StorjError; end
  class TooManyRequestError < StorjError; end
  class BandwidthLimitExceededError < StorjError; end
  class StorageLimitExceededError < StorjError; end
  class SegmentsLimitExceededError < StorjError; end
  class BucketNameInvalidError < StorjError; end
  class BucketAlreadyExistsError < StorjError; end
  class BucketNotEmptyError < StorjError; end
  class BucketNotFoundError < StorjError; end
  class ObjectKeyInvalidError < StorjError; end
  class ObjectKeyNotFoundError < StorjError; end
  class UploadDoneError < StorjError; end
  class EdgeAuthDialFailedError < StorjError; end
  class EdgeRegisterAccessFailedError < StorjError; end

  EOF = -1
  UPLINK_ERROR_INTERNAL = 0x02
  UPLINK_ERROR_CANCELED = 0x03
  UPLINK_ERROR_INVALID_HANDLE = 0x04
  UPLINK_ERROR_TOO_MANY_REQUESTS = 0x05
  UPLINK_ERROR_BANDWIDTH_LIMIT_EXCEEDED = 0x06
  UPLINK_ERROR_STORAGE_LIMIT_EXCEEDED = 0x07
  UPLINK_ERROR_SEGMENTS_LIMIT_EXCEEDED = 0x08
  UPLINK_ERROR_BUCKET_NAME_INVALID = 0x10
  UPLINK_ERROR_BUCKET_ALREADY_EXISTS = 0x11
  UPLINK_ERROR_BUCKET_NOT_EMPTY = 0x12
  UPLINK_ERROR_BUCKET_NOT_FOUND = 0x13
  UPLINK_ERROR_OBJECT_KEY_INVALID = 0x20
  UPLINK_ERROR_OBJECT_NOT_FOUND = 0x21
  UPLINK_ERROR_UPLOAD_DONE = 0x22
  EDGE_ERROR_AUTH_DIAL_FAILED = 0x30
  EDGE_ERROR_REGISTER_ACCESS_FAILED = 0x31

  CODE_TO_ERROR_MAPPING = {
    UPLINK_ERROR_INTERNAL => InternalError,
    UPLINK_ERROR_CANCELED => CanceledError,
    UPLINK_ERROR_INVALID_HANDLE => InvalidHandleError,
    UPLINK_ERROR_TOO_MANY_REQUESTS => TooManyRequestError,
    UPLINK_ERROR_BANDWIDTH_LIMIT_EXCEEDED => BandwidthLimitExceededError,
    UPLINK_ERROR_STORAGE_LIMIT_EXCEEDED => StorageLimitExceededError,
    UPLINK_ERROR_SEGMENTS_LIMIT_EXCEEDED => SegmentsLimitExceededError,
    UPLINK_ERROR_BUCKET_NAME_INVALID => BucketNameInvalidError,
    UPLINK_ERROR_BUCKET_ALREADY_EXISTS => BucketAlreadyExistsError,
    UPLINK_ERROR_BUCKET_NOT_EMPTY => BucketNotEmptyError,
    UPLINK_ERROR_BUCKET_NOT_FOUND => BucketNotFoundError,
    UPLINK_ERROR_OBJECT_KEY_INVALID => ObjectKeyInvalidError,
    UPLINK_ERROR_OBJECT_NOT_FOUND => ObjectKeyNotFoundError,
    UPLINK_ERROR_UPLOAD_DONE => UploadDoneError,
    EDGE_ERROR_AUTH_DIAL_FAILED => EdgeAuthDialFailedError,
    EDGE_ERROR_REGISTER_ACCESS_FAILED => EdgeRegisterAccessFailedError
  }.freeze
end
