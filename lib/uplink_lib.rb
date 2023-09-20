# frozen_string_literal: true

require 'ffi'

module UplinkLib
  extend FFI::Library

  ffi_lib 'libuplink.so'

  class UplinkHandle < FFI::Struct
    layout :_handle, :size_t
  end

  class UplinkAccess < FFI::Struct
    layout :_handle, :size_t
  end

  class UplinkProject < FFI::Struct
    layout :_handle, :size_t
  end

  class UplinkDownload < FFI::Struct
    layout :_handle, :size_t
  end

  class UplinkUpload < FFI::Struct
    layout :_handle, :size_t
  end

  class UplinkEncryptionKey < FFI::Struct
    layout :_handle, :size_t
  end

  class UplinkPartUpload < FFI::Struct
    layout :_handle, :size_t
  end

  class UplinkConfig < FFI::Struct
    layout :user_agent, :pointer,    # string
           :dial_timeout_milliseconds, :int32_t,
           :temp_directory, :pointer # string
  end

  class UplinkBucket < FFI::Struct
    layout :name, :string,
           :created, :int64_t
  end

  class UplinkSystemMetadata < FFI::Struct
    layout :created, :int64_t,
           :expires, :int64_t,
           :content_length, :int64_t
  end

  class UplinkCustomMetadataEntry < FFI::Struct
    layout :key, :pointer,   # string
           :key_length, :size_t,
           :value, :pointer, # string
           :value_length, :size_t
  end

  class UplinkCustomMetadata < FFI::Struct
    layout :entries, :pointer, # array of UplinkCustomMetadataEntry
           :count, :size_t
  end

  class UplinkObject < FFI::Struct
    layout :key, :string,
           :is_prefix, :bool,
           :system, UplinkSystemMetadata.val,
           :custom, UplinkCustomMetadata.val
  end

  class UplinkUploadOptions < FFI::Struct
    layout :expires, :int64_t
  end

  class UplinkDownloadOptions < FFI::Struct
    layout :offset, :int64_t,
           :length, :int64_t
  end

  class UplinkListObjectsOptions < FFI::Struct
    layout :prefix, :pointer, # string
           :cursor, :pointer, # string
           :recursive, :bool,
           :system, :bool,
           :custom, :bool
  end

  class UplinkListUploadsOptions < FFI::Struct
    layout :prefix, :pointer, # string
           :cursor, :pointer, # string
           :recursive, :bool,
           :system, :bool,
           :custom, :bool
  end

  class UplinkListBucketsOptions < FFI::Struct
    layout :cursor, :pointer # string
  end

  class UplinkObjectIterator < FFI::Struct
    layout :_handle, :size_t
  end

  class UplinkBucketIterator < FFI::Struct
    layout :_handle, :size_t
  end

  class UplinkUploadIterator < FFI::Struct
    layout :_handle, :size_t
  end

  class UplinkPartIterator < FFI::Struct
    layout :_handle, :size_t
  end

  class UplinkPermission < FFI::Struct
    layout :allow_download, :bool,
           :allow_upload, :bool,
           :allow_list, :bool,
           :allow_delete, :bool,
           :not_before, :int64_t,
           :not_after, :int64_t
  end

  class UplinkPart < FFI::Struct
    layout :part_number, :uint32_t,
           :size, :size_t,
           :modified, :int64_t,
           :etag, :string,
           :etag_length, :size_t
  end

  class UplinkSharePrefix < FFI::Struct
    layout :bucket, :pointer, # string
           :prefix, :pointer  # string
  end

  class UplinkError < FFI::Struct
    layout :code, :int32_t,
           :message, :string
  end

  class UplinkAccessResult < FFI::Struct
    layout :access, UplinkAccess.ptr,
           :error, UplinkError.ptr
  end

  class UplinkProjectResult < FFI::Struct
    layout :project, UplinkProject.ptr,
           :error, UplinkError.ptr
  end

  class UplinkBucketResult < FFI::Struct
    layout :bucket, UplinkBucket.ptr,
           :error, UplinkError.ptr
  end

  class UplinkObjectResult < FFI::Struct
    layout :object, UplinkObject.ptr,
           :error, UplinkError.ptr
  end

  class UplinkUploadResult < FFI::Struct
    layout :upload, UplinkUpload.ptr,
           :error, UplinkError.ptr
  end

  class UplinkPartUploadResult < FFI::Struct
    layout :part_upload, UplinkPartUpload.ptr,
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

  class UplinkStringResult < FFI::Struct
    layout :string, :string,
           :error, UplinkError.ptr
  end

  class UplinkEncryptionKeyResult < FFI::Struct
    layout :encryption_key, UplinkEncryptionKey.ptr,
           :error, UplinkError.ptr
  end

  class UplinkUploadInfo < FFI::Struct
    layout :upload_id, :string,
           :key, :string,
           :is_prefix, :bool,
           :system, UplinkSystemMetadata.val,
           :custom, UplinkCustomMetadata.val
  end

  class UplinkUploadInfoResult < FFI::Struct
    layout :info, UplinkUploadInfo.ptr,
           :error, UplinkError.ptr
  end

  class UplinkCommitUploadOptions < FFI::Struct
    layout :custom_metadata, UplinkCustomMetadata.val
  end

  class UplinkCommitUploadResult < FFI::Struct
    layout :object, UplinkObject.ptr,
           :error, UplinkError.ptr
  end

  class UplinkPartResult < FFI::Struct
    layout :part, UplinkPart.ptr,
           :error, UplinkError.ptr
  end

  class UplinkListUploadPartsOptions < FFI::Struct
    layout :cursor, :uint32_t
  end

  class EdgeConfig < FFI::Struct
    layout :auth_service_address, :pointer, # string
           :certificate_pem, :pointer,      # string
           :insecure_unencrypted_connection, :bool
  end

  class EdgeRegisterAccessOptions < FFI::Struct
    layout :is_public, :bool
  end

  class EdgeCredentials < FFI::Struct
    layout :access_key_id, :string,
           :secret_key, :string,
           :endpoint, :string
  end

  class EdgeCredentialsResult < FFI::Struct
    layout :credentials, EdgeCredentials.ptr,
           :error, UplinkError.ptr
  end

  class EdgeShareURLOptions < FFI::Struct
    layout :raw, :bool
  end

  class UplinkMoveObjectOptions < FFI::Struct; end
  class UplinkUploadObjectMetadataOptions < FFI::Struct; end
  class UplinkCopyObjectOptions < FFI::Struct; end

  attach_function :uplink_parse_access, [:string], UplinkAccessResult.val
  attach_function :uplink_request_access_with_passphrase, [:string, :string, :string], UplinkAccessResult.val
  attach_function :uplink_access_satellite_address, [UplinkAccess.ptr], UplinkStringResult.val
  attach_function :uplink_access_serialize, [UplinkAccess.ptr], UplinkStringResult.val
  attach_function :uplink_access_share, [UplinkAccess.ptr, UplinkPermission.val, :pointer, :long_long], UplinkAccessResult.val
  attach_function :uplink_access_override_encryption_key, [UplinkAccess.ptr, :string, :string, UplinkEncryptionKey.ptr], UplinkError.ptr
  attach_function :uplink_free_string_result, [UplinkStringResult.val], :void
  attach_function :uplink_free_access_result, [UplinkAccessResult.val], :void
  attach_function :uplink_stat_bucket, [UplinkProject.ptr, :string], UplinkBucketResult.val
  attach_function :uplink_create_bucket, [UplinkProject.ptr, :string], UplinkBucketResult.val
  attach_function :uplink_ensure_bucket, [UplinkProject.ptr, :string], UplinkBucketResult.val
  attach_function :uplink_delete_bucket, [UplinkProject.ptr, :string], UplinkBucketResult.val
  attach_function :uplink_delete_bucket_with_objects, [UplinkProject.ptr, :string], UplinkBucketResult.val
  attach_function :uplink_free_bucket_result, [UplinkBucketResult.val], :void
  attach_function :uplink_free_bucket, [UplinkBucket.ptr], :void
  attach_function :uplink_list_buckets, [UplinkProject.ptr, UplinkListBucketsOptions.ptr], UplinkBucketIterator.ptr
  attach_function :uplink_bucket_iterator_next, [UplinkBucketIterator.ptr], :bool
  attach_function :uplink_bucket_iterator_err, [UplinkBucketIterator.ptr], UplinkError.ptr
  attach_function :uplink_bucket_iterator_item, [UplinkBucketIterator.ptr], UplinkBucket.ptr
  attach_function :uplink_free_bucket_iterator, [UplinkBucketIterator.ptr], :void
  attach_function :uplink_config_request_access_with_passphrase, [UplinkConfig.val, :string, :string, :string], UplinkAccessResult.val
  attach_function :uplink_config_open_project, [UplinkConfig.val, UplinkAccess.ptr], UplinkProjectResult.val
  attach_function :uplink_copy_object, [UplinkProject.ptr, :string, :string, :string, :string, UplinkCopyObjectOptions.ptr], UplinkObjectResult.val
  attach_function :uplink_download_object, [UplinkProject.ptr, :string, :string, UplinkDownloadOptions.ptr], UplinkDownloadResult.val
  attach_function :uplink_download_read, [UplinkDownload.ptr, :pointer, :size_t], UplinkReadResult.val
  attach_function :uplink_download_info, [UplinkDownload.ptr], UplinkObjectResult.val
  attach_function :uplink_free_read_result, [UplinkReadResult.val], :void
  attach_function :uplink_close_download, [UplinkDownload.ptr], UplinkError.ptr
  attach_function :uplink_free_download_result, [UplinkDownloadResult.val], :void
  attach_function :edge_register_access, [EdgeConfig.val, UplinkAccess.ptr, EdgeRegisterAccessOptions.ptr], EdgeCredentialsResult.val
  attach_function :edge_free_credentials_result, [EdgeCredentialsResult.val], :void
  attach_function :edge_free_credentials, [EdgeCredentials.ptr], :void
  attach_function :edge_join_share_url, [:string, :string, :string, :string, EdgeShareURLOptions.ptr], UplinkStringResult.val
  attach_function :uplink_derive_encryption_key, [:string, :pointer, :size_t], UplinkEncryptionKeyResult.val
  attach_function :uplink_free_encryption_key_result, [UplinkEncryptionKeyResult.val], :void
  attach_function :uplink_free_error, [UplinkError.ptr], :void
  attach_function :uplink_internal_UniverseIsEmpty, [], :uchar
  attach_function :uplink_move_object, [UplinkProject.ptr, :string, :string, :string, :string, UplinkMoveObjectOptions.ptr], UplinkError.ptr
  attach_function :uplink_begin_upload, [UplinkProject.ptr, :string, :string, UplinkUploadOptions.ptr], UplinkUploadInfoResult.val
  attach_function :uplink_free_upload_info_result, [UplinkUploadInfoResult.val], :void
  attach_function :uplink_free_upload_info, [UplinkUploadInfo.ptr], :void
  attach_function :uplink_commit_upload, [UplinkProject.ptr, :string, :string, :string, UplinkCommitUploadOptions.ptr], UplinkCommitUploadResult.val
  attach_function :uplink_free_commit_upload_result, [UplinkCommitUploadResult.val], :void
  attach_function :uplink_abort_upload, [UplinkProject.ptr, :string, :string, :string], UplinkError.ptr
  attach_function :uplink_upload_part, [UplinkProject.ptr, :string, :string, :string, :uint32_t], UplinkPartUploadResult.val
  attach_function :uplink_part_upload_write, [UplinkPartUpload.ptr, :pointer, :size_t], UplinkWriteResult.val
  attach_function :uplink_part_upload_commit, [UplinkPartUpload.ptr], UplinkError.ptr
  attach_function :uplink_part_upload_abort, [UplinkPartUpload.ptr], UplinkError.ptr
  attach_function :uplink_part_upload_set_etag, [UplinkPartUpload.ptr, :string], UplinkError.ptr
  attach_function :uplink_part_upload_info, [UplinkPartUpload.ptr], UplinkPartResult.val
  attach_function :uplink_free_part_result, [UplinkPartResult.val], :void
  attach_function :uplink_free_part_upload_result, [UplinkPartUploadResult.val], :void
  attach_function :uplink_free_part, [UplinkPart.ptr], :void
  attach_function :uplink_list_uploads, [UplinkProject.ptr, :string, UplinkListUploadsOptions.ptr], UplinkUploadIterator.ptr
  attach_function :uplink_upload_iterator_next, [UplinkUploadIterator.ptr], :bool
  attach_function :uplink_upload_iterator_err, [UplinkUploadIterator.ptr], UplinkError.ptr
  attach_function :uplink_upload_iterator_item, [UplinkUploadIterator.ptr], UplinkUploadInfo.ptr
  attach_function :uplink_free_upload_iterator, [UplinkUploadIterator.ptr], :void
  attach_function :uplink_list_upload_parts, [UplinkProject.ptr, :string, :string, :string, UplinkListUploadPartsOptions.ptr], UplinkPartIterator.ptr
  attach_function :uplink_part_iterator_next, [UplinkPartIterator.ptr], :bool
  attach_function :uplink_part_iterator_err, [UplinkPartIterator.ptr], UplinkError.ptr
  attach_function :uplink_part_iterator_item, [UplinkPartIterator.ptr], UplinkPart.ptr
  attach_function :uplink_free_part_iterator, [UplinkPartIterator.ptr], :void
  attach_function :uplink_stat_object, [UplinkProject.ptr, :string, :string], UplinkObjectResult.val
  attach_function :uplink_delete_object, [UplinkProject.ptr, :string, :string], UplinkObjectResult.val
  attach_function :uplink_free_object_result, [UplinkObjectResult.val], :void
  attach_function :uplink_free_object, [UplinkObject.ptr], :void
  attach_function :uplink_update_object_metadata, [UplinkProject.ptr, :string, :string, UplinkCustomMetadata.val, UplinkUploadObjectMetadataOptions.ptr], UplinkError.ptr
  attach_function :uplink_list_objects, [UplinkProject.ptr, :string, UplinkListObjectsOptions.ptr], UplinkObjectIterator.ptr
  attach_function :uplink_object_iterator_next, [UplinkObjectIterator.ptr], :bool
  attach_function :uplink_object_iterator_err, [UplinkObjectIterator.ptr], UplinkError.ptr
  attach_function :uplink_object_iterator_item, [UplinkObjectIterator.ptr], UplinkObject.ptr
  attach_function :uplink_free_object_iterator, [UplinkObjectIterator.ptr], :void
  attach_function :uplink_open_project, [UplinkAccess.ptr], UplinkProjectResult.val
  attach_function :uplink_close_project, [UplinkProject.ptr], UplinkError.ptr
  attach_function :uplink_free_project_result, [UplinkProjectResult.val], :void
  attach_function :uplink_revoke_access, [UplinkProject.ptr, UplinkAccess.ptr], UplinkError.ptr
  attach_function :uplink_upload_object, [UplinkProject.ptr, :string, :string, UplinkUploadOptions.ptr], UplinkUploadResult.val
  attach_function :uplink_upload_write, [UplinkUpload.ptr, :pointer, :size_t], UplinkWriteResult.val
  attach_function :uplink_upload_commit, [UplinkUpload.ptr], UplinkError.ptr
  attach_function :uplink_upload_abort, [UplinkUpload.ptr], UplinkError.ptr
  attach_function :uplink_upload_info, [UplinkUpload.ptr], UplinkObjectResult.val
  attach_function :uplink_upload_set_custom_metadata, [UplinkUpload.ptr, UplinkCustomMetadata.val], UplinkError.ptr
  attach_function :uplink_free_write_result, [UplinkWriteResult.val], :void
  attach_function :uplink_free_upload_result, [UplinkUploadResult.val], :void
end
