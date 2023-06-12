# frozen_string_literal: true

require 'ffi'

module UplinkLib
  extend FFI::Library

  ffi_lib 'libuplink.so'

  class UplinkAccess < FFI::Struct
    layout :_handle, :size_t
  end

  class UplinkEncryptionKey < FFI::Struct
    layout :_handle, :size_t
  end

  class UplinkBucket < FFI::Struct
    layout :name, :string,
           :created, :int64_t
  end

  class UplinkProject < FFI::Struct
    layout :_handle, :size_t
  end

  class UplinkUpload < FFI::Struct
    layout :_handle, :size_t
  end

  class UplinkDownload < FFI::Struct
    layout :_handle, :size_t
  end

  class UplinkObjectIterator < FFI::Struct
    layout :_handle, :size_t
  end

  class UplinkUploadOptions < FFI::Struct
    layout :expires, :int64_t
  end

  class UplinkDownloadOptions < FFI::Struct
    layout :offset, :int64_t,
           :length, :int64_t
  end

  class UplinkSystemMetadata < FFI::Struct
    layout :created, :int64_t,
           :expires, :int64_t,
           :content_length, :int64_t
  end

  class UplinkCustomMetadataEntry < FFI::Struct
    layout :key, :pointer, # string
           :key_length, :size_t,
           :value, :pointer, # string
           :value_length, :size_t
  end

  class UplinkCustomMetadata < FFI::Struct
    layout :entries, :pointer, # array of UplinkCustomMetadataEntry
           :count, :size_t
  end

  class UplinkUploadObjectMetadataOptions < FFI::Struct; end

  class UplinkObject < FFI::Struct
    layout :key, :string,
           :is_prefix, :bool,
           :system, UplinkSystemMetadata.val,
           :custom, UplinkCustomMetadata.val
  end

  class UplinkListObjectsOptions < FFI::Struct
    layout :prefix, :pointer, # string
           :cursor, :pointer, # string
           :recursive, :bool,
           :system, :bool,
           :custom, :bool
  end

  class UplinkError < FFI::Struct
    layout :code, :int32_t,
           :message, :string
  end

  class UplinkAccessResult < FFI::Struct
    layout :access, UplinkAccess.ptr,
           :error, UplinkError.ptr
  end

  class UplinkEncryptionKeyResult < FFI::Struct
    layout :encryption_key, UplinkEncryptionKey.ptr,
           :error, UplinkError.ptr
  end

  class UplinkBucketResult < FFI::Struct
    layout :bucket, UplinkBucket.ptr,
           :error, UplinkError.ptr
  end

  class UplinkProjectResult < FFI::Struct
    layout :project, UplinkProject.ptr,
           :error, UplinkError.ptr
  end

  class UplinkUploadResult < FFI::Struct
    layout :upload, UplinkUpload.ptr,
           :error, UplinkError.ptr
  end

  class UplinkDownloadResult < FFI::Struct
    layout :download, UplinkDownload.ptr,
           :error, UplinkError.ptr
  end

  class UplinkWriteResult < FFI::Struct
    layout :bytes_written, :size_t,
           :error, UplinkError.ptr
  end

  class UplinkReadResult < FFI::Struct
    layout :bytes_read, :size_t,
           :error, UplinkError.ptr
  end

  class UplinkObjectResult < FFI::Struct
    layout :object, UplinkObject.ptr,
           :error, UplinkError.ptr
  end

  attach_function :uplink_parse_access, [:string], UplinkAccessResult.val
  attach_function :uplink_request_access_with_passphrase, %i[string string string], UplinkAccessResult.val
  attach_function :uplink_free_access_result, [UplinkAccessResult.val], :void

  attach_function :uplink_open_project, [UplinkAccess.ptr], UplinkProjectResult.val
  attach_function :uplink_close_project, [UplinkProject.ptr], UplinkError.ptr
  attach_function :uplink_free_project_result, [UplinkProjectResult.val], :void

  attach_function :uplink_create_bucket, [UplinkProject.ptr, :string], UplinkBucketResult.val
  attach_function :uplink_ensure_bucket, [UplinkProject.ptr, :string], UplinkBucketResult.val
  attach_function :uplink_stat_bucket, [UplinkProject.ptr, :string], UplinkBucketResult.val
  attach_function :uplink_delete_bucket, [UplinkProject.ptr, :string], UplinkBucketResult.val
  attach_function :uplink_delete_bucket_with_objects, [UplinkProject.ptr, :string], UplinkBucketResult.val
  attach_function :uplink_free_bucket_result, [UplinkBucketResult.val], :void

  attach_function :uplink_upload_object, [UplinkProject.ptr, :string, :string, UplinkUploadOptions.ptr], UplinkUploadResult.val
  attach_function :uplink_free_upload_result, [UplinkUploadResult.val], :void
  attach_function :uplink_upload_commit, [UplinkUpload.ptr], UplinkError.ptr
  attach_function :uplink_upload_set_custom_metadata, [UplinkUpload.ptr, UplinkCustomMetadata.val], UplinkError.ptr

  attach_function :uplink_upload_write, [UplinkUpload.ptr, :pointer, :size_t], UplinkWriteResult.val
  attach_function :uplink_free_write_result, [UplinkWriteResult.val], :void
  attach_function :uplink_upload_abort, [UplinkUpload.ptr], UplinkError.ptr

  attach_function :uplink_download_object, [UplinkProject.ptr, :string, :string, UplinkDownloadOptions.ptr], UplinkDownloadResult.val
  attach_function :uplink_free_download_result, [UplinkDownloadResult.val], :void
  attach_function :uplink_close_download, [UplinkDownload.ptr], UplinkError.ptr

  attach_function :uplink_download_read, [UplinkDownload.ptr, :pointer, :size_t], UplinkReadResult.val
  attach_function :uplink_free_read_result, [UplinkReadResult.val], :void

  attach_function :uplink_upload_info, [UplinkUpload.ptr], UplinkObjectResult.val
  attach_function :uplink_download_info, [UplinkDownload.ptr], UplinkObjectResult.val
  attach_function :uplink_stat_object, [UplinkProject.ptr, :string, :string], UplinkObjectResult.val
  attach_function :uplink_delete_object, [UplinkProject.ptr, :string, :string], UplinkObjectResult.val
  attach_function :uplink_free_object_result, [UplinkObjectResult.val], :void
  attach_function :uplink_free_object, [UplinkObject.ptr], :void
  attach_function :uplink_update_object_metadata, [UplinkProject.ptr, :string, :string, UplinkCustomMetadata.val, UplinkUploadObjectMetadataOptions.ptr], UplinkError.ptr

  attach_function :uplink_list_objects, [UplinkProject.ptr, :string, UplinkListObjectsOptions.ptr], UplinkObjectIterator.ptr
  attach_function :uplink_object_iterator_next, [UplinkObjectIterator.ptr], :bool
  attach_function :uplink_object_iterator_item, [UplinkObjectIterator.ptr], UplinkObject.ptr
  attach_function :uplink_object_iterator_err, [UplinkObjectIterator.ptr], UplinkError.ptr
  attach_function :uplink_free_object_iterator, [UplinkObjectIterator.ptr], :void

  attach_function :uplink_free_error, [UplinkError.ptr], :void
end

module Uplink
  class << self
    def parse_access(access_string)
      result = UplinkLib.uplink_parse_access(access_string)
      ErrorUtil.handle_result_error(result)

      yield Access.new(result)
    ensure
      UplinkLib.uplink_free_access_result(result) if result
    end

    def request_access_with_passphrase(satellite_address, api_key, passphrase)
      result = UplinkLib.uplink_request_access_with_passphrase(satellite_address, api_key, passphrase)
      ErrorUtil.handle_result_error(result)

      yield Access.new(result)
    ensure
      UplinkLib.uplink_free_access_result(result) if result
    end
  end

  class Access
    def initialize(access_result)
      @access = access_result[:access]
    end

    def open_project(auto_close: true)
      result = UplinkLib.uplink_open_project(@access)
      ErrorUtil.handle_result_error(result)

      project = Project.new(result)

      yield project
    ensure
      project.close if auto_close && project
      UplinkLib.uplink_free_project_result(result) if result
    end
  end

  class Project
    def initialize(project_result)
      @project = project_result[:project]
    end

    def create_bucket(bucket_name)
      result = UplinkLib.uplink_create_bucket(@project, bucket_name)
      ErrorUtil.handle_result_error(result)

      Bucket.new(result)
    ensure
      UplinkLib.uplink_free_bucket_result(result) if result
    end

    def ensure_bucket(bucket_name)
      result = UplinkLib.uplink_ensure_bucket(@project, bucket_name)
      ErrorUtil.handle_result_error(result)

      Bucket.new(result)
    ensure
      UplinkLib.uplink_free_bucket_result(result) if result
    end

    def stat_bucket(bucket_name)
      result = UplinkLib.uplink_stat_bucket(@project, bucket_name)
      ErrorUtil.handle_result_error(result)

      Bucket.new(result)
    ensure
      UplinkLib.uplink_free_bucket_result(result) if result
    end

    def delete_bucket(bucket_name)
      result = UplinkLib.uplink_delete_bucket(@project, bucket_name)
      ErrorUtil.handle_result_error(result)

      Bucket.new(result)
    ensure
      UplinkLib.uplink_free_bucket_result(result) if result
    end

    def delete_bucket_with_objects(bucket_name)
      result = UplinkLib.uplink_delete_bucket_with_objects(@project, bucket_name)
      ErrorUtil.handle_result_error(result)

      Bucket.new(result)
    ensure
      UplinkLib.uplink_free_bucket_result(result) if result
    end

    def upload_object(bucket_name, object_key, options = nil)
      upload_options = nil
      if options && !options.empty?
        upload_options = UplinkLib::UplinkUploadOptions.new
        upload_options[:expires] = options[:expires]&.to_i
      end

      result = UplinkLib.uplink_upload_object(@project, bucket_name, object_key, upload_options)
      ErrorUtil.handle_result_error(result)

      yield Upload.new(result)
    ensure
      UplinkLib.uplink_free_upload_result(result) if result
    end

    def download_object(bucket_name, object_key, options = nil, auto_close: true)
      download_options = nil
      if options && !options.empty?
        download_options = UplinkLib::UplinkDownloadOptions.new
        download_options[:offset] = options[:offset]&.to_i if options[:offset]
        download_options[:length] = options[:length]&.to_i if options[:length]
      end

      result = UplinkLib.uplink_download_object(@project, bucket_name, object_key, download_options)
      ErrorUtil.handle_result_error(result)

      download = Download.new(result)

      yield download
    ensure
      download.close if auto_close && download
      UplinkLib.uplink_free_download_result(result) if result
    end

    def stat_object(bucket_name, object_key)
      result = UplinkLib.uplink_stat_object(@project, bucket_name, object_key)
      ErrorUtil.handle_result_error(result)

      Object.new(result)
    ensure
      UplinkLib.uplink_free_object_result(result) if result
    end

    def list_objects(bucket_name, options = nil)
      list_options = nil
      if options && !options.empty?
        list_options = UplinkLib::UplinkListObjectsOptions.new
        cursor = FFI::MemoryPointer.from_string(options[:cursor]) if options[:cursor]
        prefix = FFI::MemoryPointer.from_string(options[:prefix]) if options[:prefix]
        list_options[:cursor] = cursor
        list_options[:prefix] = prefix
        list_options[:recursive] = options[:recursive]
        list_options[:system] = options[:system]
        list_options[:custom] = options[:custom]
      end

      iterator = UplinkLib.uplink_list_objects(@project, bucket_name, list_options)
      yield ObjectIterator.new(iterator)
    ensure
      UplinkLib.uplink_free_object_iterator(iterator) if iterator
    end

    def update_object_metadata(bucket_name, object_key, new_metadata, options = nil)
      count = new_metadata.size
      mem_entries = FFI::MemoryPointer.new(UplinkLib::UplinkCustomMetadataEntry, count)

      new_metadata.to_a.each_with_index do |(key, value), i|
        mem_key = FFI::MemoryPointer.from_string(key.to_s) if key
        mem_value = FFI::MemoryPointer.from_string(value.to_s) if value

        entry = UplinkLib::UplinkCustomMetadataEntry.new(mem_entries + (i * UplinkLib::UplinkCustomMetadataEntry.size))
        entry[:key] = mem_key
        entry[:key_length] = key ? key.length : 0
        entry[:value] = mem_value
        entry[:value_length] = value ? value.to_s.length : 0
      end

      custom_metadata = UplinkLib::UplinkCustomMetadata.new
      custom_metadata[:count] = count
      custom_metadata[:entries] = mem_entries

      error = UplinkLib.uplink_update_object_metadata(@project, bucket_name, object_key, custom_metadata, options)
      ErrorUtil.handle_error(error)
    ensure
      UplinkLib.uplink_free_error(error) if error
    end

    def delete_object(bucket_name, object_key)
      result = UplinkLib.uplink_delete_object(@project, bucket_name, object_key)
      ErrorUtil.handle_result_error(result)

      Object.new(result)
    ensure
      UplinkLib.uplink_free_object_result(result) if result
    end

    def close
      error = UplinkLib.uplink_close_project(@project)
      ErrorUtil.handle_error(error)
    ensure
      UplinkLib.uplink_free_error(error) if error
    end
  end

  class Bucket
    attr_reader :name, :created

    def initialize(bucket_result)
      return if bucket_result[:bucket].null?

      @name = bucket_result[:bucket][:name]
      @created = bucket_result[:bucket][:created]
    end
  end

  class Upload
    def initialize(upload_result)
      @upload = upload_result[:upload]
    end

    def write(bytes, length)
      raise ArgumentError, 'bytes argument is nil' if bytes.nil?

      if bytes.is_a?(Array) && bytes.first.is_a?(Integer)
        mem_bytes = FFI::MemoryPointer.new(:uint8, length)
        mem_bytes.write_array_of_uint8(bytes)
      else
        mem_bytes = bytes
      end

      result = UplinkLib.uplink_upload_write(@upload, mem_bytes, length)
      abort unless result[:error].null?
      ErrorUtil.handle_result_error(result)

      bytes_written = result[:bytes_written]

      bytes_written
    ensure
      UplinkLib.uplink_free_write_result(result) if result
    end

    def set_custom_metadata(custom)
      count = custom.size
      mem_entries = FFI::MemoryPointer.new(UplinkLib::UplinkCustomMetadataEntry, count)

      custom.to_a.each_with_index do |(key, value), i|
        mem_key = FFI::MemoryPointer.from_string(key.to_s) if key
        mem_value = FFI::MemoryPointer.from_string(value.to_s) if value

        entry = UplinkLib::UplinkCustomMetadataEntry.new(mem_entries + (i * UplinkLib::UplinkCustomMetadataEntry.size))
        entry[:key] = mem_key
        entry[:key_length] = key ? key.length : 0
        entry[:value] = mem_value
        entry[:value_length] = value ? value.to_s.length : 0
      end

      custom_metadata = UplinkLib::UplinkCustomMetadata.new
      custom_metadata[:count] = count
      custom_metadata[:entries] = mem_entries

      error = UplinkLib.uplink_upload_set_custom_metadata(@upload, custom_metadata)
      ErrorUtil.handle_error(error)
    ensure
      UplinkLib.uplink_free_error(error) if error
    end

    def commit
      error = UplinkLib.uplink_upload_commit(@upload)
      ErrorUtil.handle_error(error)
    ensure
      UplinkLib.uplink_free_error(error) if error
    end

    def abort
      error = UplinkLib.uplink_upload_abort(@upload)
      ErrorUtil.handle_error(error)
    ensure
      UplinkLib.uplink_free_error(error) if error
    end

    def info
      result = UplinkLib.uplink_upload_info(@upload)
      ErrorUtil.handle_result_error(result)

      Object.new(result)
    ensure
      UplinkLib.uplink_free_object_result(result) if result
    end
  end

  class Download
    def initialize(download_result)
      @download = download_result[:download]
    end

    def read(bytes, length)
      raise ArgumentError, 'bytes argument is nil' if bytes.nil?

      mem_bytes = FFI::MemoryPointer.new(:uint8, length)
      result = UplinkLib.uplink_download_read(@download, mem_bytes, length)

      error_code = ErrorUtil.handle_result_error(result)
      is_eof = (error_code == EOF)

      bytes_read = result[:bytes_read]
      bytes.concat(mem_bytes.read_array_of_uint8(bytes_read)) if bytes_read.positive?

      [bytes_read, is_eof]
    ensure
      UplinkLib.uplink_free_read_result(result) if result
    end

    def info
      result = UplinkLib.uplink_download_info(@download)
      ErrorUtil.handle_result_error(result)

      Object.new(result)
    ensure
      UplinkLib.uplink_free_object_result(result) if result
    end

    def close
      error = UplinkLib.uplink_close_download(@download)
      ErrorUtil.handle_error(error)
    ensure
      UplinkLib.uplink_free_error(error) if error
    end
  end

  class Object
    attr_reader :key, :is_prefix, :created, :expires, :content_length, :custom

    def initialize(object_result, object = nil)
      init_attributes(object_result.nil? || object_result.null? ? object : object_result[:object])
    end

    private

    def init_attributes(object)
      return if object.nil? || object.null?

      @key = object[:key]
      @is_prefix = object[:is_prefix]

      unless object[:system].null?
        @created = object[:system][:created]
        @expires = object[:system][:expires]
        @content_length = object[:system][:content_length]
      end

      init_custom(object)
    end

    def init_custom(object)
      @custom = {}

      return if object[:custom].null?

      count = object[:custom][:count]
      mem_entries = object[:custom][:entries]

      return if mem_entries.null?

      count.times do |i|
        entry = UplinkLib::UplinkCustomMetadataEntry.new(mem_entries + (i * UplinkLib::UplinkCustomMetadataEntry.size))
        next if entry.null?

        key = entry[:key].read_string
        value = entry[:value].read_string
        @custom[key] = value
      end
    end
  end

  class ObjectIterator
    def initialize(object_iterator)
      @object_iterator = object_iterator
    end

    def next?
      has_next = UplinkLib.uplink_object_iterator_next(@object_iterator)
      unless has_next
        begin
          error = UplinkLib.uplink_object_iterator_err(@object_iterator)
          ErrorUtil.handle_error(error)
        ensure
          UplinkLib.uplink_free_error(error) if error
        end
      end

      has_next
    end

    def item
      object = UplinkLib.uplink_object_iterator_item(@object_iterator)
      Object.new(nil, object)
    ensure
      UplinkLib.uplink_free_object(object) if object
    end
  end

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
