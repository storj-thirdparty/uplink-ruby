# frozen_string_literal: true

module Uplink
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

    def list_buckets(options = nil)
      list_options = nil
      if options && !options.empty?
        list_options = UplinkLib::UplinkListBucketsOptions.new
        cursor = FFI::MemoryPointer.from_string(options[:cursor]) if options[:cursor]
        list_options[:cursor] = cursor
      end

      iterator = UplinkLib.uplink_list_buckets(@project, list_options)

      yield BucketIterator.new(iterator)
    ensure
      UplinkLib.uplink_free_bucket_iterator(iterator) if iterator
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
      upload_options = UplinkUtil.build_upload_options(options)

      result = UplinkLib.uplink_upload_object(@project, bucket_name, object_key, upload_options)
      ErrorUtil.handle_result_error(result)

      yield Upload.new(result)
    ensure
      UplinkLib.uplink_free_upload_result(result) if result
    end

    def begin_upload(bucket_name, object_key, options = nil)
      upload_options = UplinkUtil.build_upload_options(options)

      result = UplinkLib.uplink_begin_upload(@project, bucket_name, object_key, upload_options)
      ErrorUtil.handle_result_error(result)

      UploadInfo.new(result)
    ensure
      UplinkLib.uplink_free_upload_info_result(result) if result
    end

    def upload_part(bucket_name, object_key, upload_id, part_number)
      result = UplinkLib.uplink_upload_part(@project, bucket_name, object_key, upload_id, part_number)
      ErrorUtil.handle_result_error(result)

      yield PartUpload.new(result)
    ensure
      UplinkLib.uplink_free_part_upload_result(result) if result
    end

    def commit_upload(bucket_name, object_key, upload_id, options = nil)
      upload_options = nil
      if options && !options.empty?
        custom_metadata = nil

        if options[:custom_metadata] && !options[:custom_metadata].empty?
          custom_metadata = UplinkUtil.build_custom_metadata(options[:custom_metadata])
        end

        upload_options = UplinkLib::UplinkCommitUploadOptions.new
        upload_options[:custom_metadata] = custom_metadata
      end

      result = UplinkLib.uplink_commit_upload(@project, bucket_name, object_key, upload_id, upload_options)
      ErrorUtil.handle_result_error(result)

      Object.new(result)
    ensure
      UplinkLib.uplink_free_commit_upload_result(result) if result
    end

    def abort_upload(bucket_name, object_key, upload_id)
      error = UplinkLib.uplink_abort_upload(@project, bucket_name, object_key, upload_id)
      ErrorUtil.handle_error(error)
    ensure
      UplinkLib.uplink_free_error(error) if error
    end

    def list_uploads(bucket_name, options = nil)
      list_options = nil
      if options && !options.empty?
        list_options = UplinkLib::UplinkListUploadsOptions.new
        cursor = FFI::MemoryPointer.from_string(options[:cursor]) if options[:cursor]
        prefix = FFI::MemoryPointer.from_string(options[:prefix]) if options[:prefix]
        list_options[:cursor] = cursor
        list_options[:prefix] = prefix
        list_options[:recursive] = options[:recursive]
        list_options[:system] = options[:system]
        list_options[:custom] = options[:custom]
      end

      iterator = UplinkLib.uplink_list_uploads(@project, bucket_name, list_options)

      yield UploadIterator.new(iterator)
    ensure
      UplinkLib.uplink_free_upload_iterator(iterator) if iterator
    end

    def list_upload_parts(bucket_name, object_key, upload_id, options = nil)
      list_options = nil
      if options && !options.empty?
        list_options = UplinkLib::UplinkListUploadPartsOptions.new
        cursor = options[:cursor].to_i if options[:cursor]
        list_options[:cursor] = cursor || 0
      end

      iterator = UplinkLib.uplink_list_upload_parts(@project, bucket_name, object_key, upload_id, list_options)

      yield UploadPartIterator.new(iterator)
    ensure
      UplinkLib.uplink_free_part_iterator(iterator) if iterator
    end

    def download_object(bucket_name, object_key, options = nil, auto_close: true)
      download_options = nil
      if options && !options.empty?
        download_options = UplinkLib::UplinkDownloadOptions.new
        download_options[:offset] = options[:offset].to_i if options[:offset]
        download_options[:length] = options[:length].to_i if options[:length]
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
      custom_metadata = UplinkUtil.build_custom_metadata(new_metadata)

      error = UplinkLib.uplink_update_object_metadata(@project, bucket_name, object_key, custom_metadata, options)
      ErrorUtil.handle_error(error)
    ensure
      UplinkLib.uplink_free_error(error) if error
    end

    def copy_object(old_bucket_name, old_object_key, new_bucket_name, new_object_key, options = nil)
      result = UplinkLib.uplink_copy_object(@project, old_bucket_name, old_object_key, new_bucket_name, new_object_key, options)
      ErrorUtil.handle_result_error(result)

      Object.new(result)
    ensure
      UplinkLib.uplink_free_object_result(result) if result
    end

    def move_object(old_bucket_name, old_object_key, new_bucket_name, new_object_key, options = nil)
      error = UplinkLib.uplink_move_object(@project, old_bucket_name, old_object_key, new_bucket_name, new_object_key, options)
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

    def revoke_access(access)
      error = UplinkLib.uplink_revoke_access(@project, access&.access)
      ErrorUtil.handle_error(error)
    ensure
      UplinkLib.uplink_free_error(error) if error
    end

    def close
      error = UplinkLib.uplink_close_project(@project)
      ErrorUtil.handle_error(error)
    ensure
      UplinkLib.uplink_free_error(error) if error
    end
  end
end
