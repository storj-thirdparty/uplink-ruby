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
