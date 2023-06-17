# frozen_string_literal: true

require 'uplink_lib'
require 'ffi'

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

    def request_access_with_passphrase_and_config(config, satellite_address, api_key, passphrase)
      config_options = UplinkUtil.build_uplink_config(config)

      result = UplinkLib.uplink_config_request_access_with_passphrase(config_options, satellite_address, api_key, passphrase)
      ErrorUtil.handle_result_error(result)

      yield Access.new(result)
    ensure
      UplinkLib.uplink_free_access_result(result) if result
    end

    def derive_encryption_key(passphrase, salt, length)
      raise ArgumentError, 'salt argument is not a string' unless salt.is_a?(String)

      result = UplinkLib.uplink_derive_encryption_key(passphrase, salt, length)
      ErrorUtil.handle_result_error(result)

      yield result[:encryption_key]
    ensure
      UplinkLib.uplink_free_encryption_key_result(result) if result
    end

    def internal_universe_is_empty?
      UplinkLib.uplink_internal_UniverseIsEmpty != 0
    end
  end

  class Access
    attr_reader :access

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

    def open_project_with_config(config, auto_close: true)
      config_options = UplinkUtil.build_uplink_config(config)

      result = UplinkLib.uplink_config_open_project(config_options, @access)
      ErrorUtil.handle_result_error(result)

      project = Project.new(result)

      yield project
    ensure
      project.close if auto_close && project
      UplinkLib.uplink_free_project_result(result) if result
    end

    def satellite_address
      result = UplinkLib.uplink_access_satellite_address(@access)
      ErrorUtil.handle_result_error(result)

      result[:string]
    ensure
      UplinkLib.uplink_free_string_result(result) if result
    end

    def serialize
      result = UplinkLib.uplink_access_serialize(@access)
      ErrorUtil.handle_result_error(result)

      result[:string]
    ensure
      UplinkLib.uplink_free_string_result(result) if result
    end

    def share(permission, prefixes)
      permission_options = UplinkLib::UplinkPermission.new
      if permission && !permission.empty?
        permission_options[:allow_download] = permission[:allow_download]
        permission_options[:allow_upload] = permission[:allow_upload]
        permission_options[:allow_list] = permission[:allow_list]
        permission_options[:allow_delete] = permission[:allow_delete]
        permission_options[:not_before] = permission[:not_before].to_i if permission[:not_before]
        permission_options[:not_after] = permission[:not_after].to_i if permission[:not_after]
      end

      prefixes_count = prefixes&.size || 0
      mem_prefixes = nil

      if prefixes_count.positive?
        mem_prefixes = FFI::MemoryPointer.new(UplinkLib::UplinkSharePrefix, prefixes_count)

        prefixes.each_with_index do |prefix, i|
          bucket = FFI::MemoryPointer.from_string(prefix[:bucket]) if prefix[:bucket]
          prefix_val = FFI::MemoryPointer.from_string(prefix[:prefix]) if prefix[:prefix]

          prefix_entry = UplinkLib::UplinkSharePrefix.new(mem_prefixes + (i * UplinkLib::UplinkSharePrefix.size))
          prefix_entry[:bucket] = bucket
          prefix_entry[:prefix] = prefix_val
        end
      end

      result = UplinkLib.uplink_access_share(@access, permission_options, mem_prefixes, prefixes_count)
      ErrorUtil.handle_result_error(result)

      yield Access.new(result)
    ensure
      UplinkLib.uplink_free_access_result(result) if result
    end

    def override_encryption_key(bucket, prefix, encryption_key)
      error = UplinkLib.uplink_access_override_encryption_key(@access, bucket, prefix, encryption_key)
      ErrorUtil.handle_error(error)
    ensure
      UplinkLib.uplink_free_error(error) if error
    end

    def edge_register_access(config, options = nil)
      register_config = UplinkLib::EdgeConfig.new

      auth_service_address = FFI::MemoryPointer.from_string(config[:auth_service_address]) if config[:auth_service_address]
      certificate_pem = FFI::MemoryPointer.from_string(config[:certificate_pem]) if config[:certificate_pem]
      register_config[:auth_service_address] = auth_service_address
      register_config[:certificate_pem] = certificate_pem

      register_options = nil
      if options && !options.empty?
        register_options = UplinkLib::EdgeRegisterAccessOptions.new
        register_options[:is_public] = options[:is_public]
      end

      result = UplinkLib.edge_register_access(register_config, @access, register_options)
      ErrorUtil.handle_result_error(result)

      EdgeCredential.new(result)
    ensure
      UplinkLib.edge_free_credentials_result(result) if result
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

  class Bucket
    attr_reader :name, :created

    def initialize(bucket_result, bucket = nil)
      init_attributes(bucket_result.nil? || bucket_result.null? ? bucket : bucket_result[:bucket])
    end

    private

    def init_attributes(bucket)
      return if bucket.nil? || bucket.null?

      @name = bucket[:name]
      @created = bucket[:created]
    end
  end

  class BucketIterator
    def initialize(bucket_iterator)
      @bucket_iterator = bucket_iterator
    end

    def next?
      has_next = UplinkLib.uplink_bucket_iterator_next(@bucket_iterator)
      unless has_next
        begin
          error = UplinkLib.uplink_bucket_iterator_err(@bucket_iterator)
          ErrorUtil.handle_error(error)
        ensure
          UplinkLib.uplink_free_error(error) if error
        end
      end

      has_next
    end

    def item
      bucket = UplinkLib.uplink_bucket_iterator_item(@bucket_iterator)
      Bucket.new(nil, bucket)
    ensure
      UplinkLib.uplink_free_bucket(bucket) if bucket
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

      result[:bytes_written]
    ensure
      UplinkLib.uplink_free_write_result(result) if result
    end

    def set_custom_metadata(custom)
      custom_metadata = UplinkUtil.build_custom_metadata(custom)

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

  class UploadInfo
    attr_reader :upload_id, :key, :is_prefix, :created, :expires, :content_length, :custom

    def initialize(upload_info_result, upload_info = nil)
      init_attributes(upload_info_result.nil? || upload_info_result.null? ? upload_info : upload_info_result[:info])
    end

    private

    def init_attributes(upload_info)
      return if upload_info.nil? || upload_info.null?

      @upload_id = upload_info[:upload_id]
      @key = upload_info[:key]
      @is_prefix = upload_info[:is_prefix]
      @created, @expires, @content_length = UplinkUtil.get_system_values(upload_info)
      @custom = UplinkUtil.get_custom_metadata(upload_info)
    end
  end

  class PartUpload
    def initialize(part_upload_result)
      @part_upload = part_upload_result[:part_upload]
    end

    def write(bytes, length)
      raise ArgumentError, 'bytes argument is nil' if bytes.nil?

      if bytes.is_a?(Array) && bytes.first.is_a?(Integer)
        mem_bytes = FFI::MemoryPointer.new(:uint8, length)
        mem_bytes.write_array_of_uint8(bytes)
      else
        mem_bytes = bytes
      end

      result = UplinkLib.uplink_part_upload_write(@part_upload, mem_bytes, length)
      abort unless result[:error].null?
      ErrorUtil.handle_result_error(result)

      result[:bytes_written]
    ensure
      UplinkLib.uplink_free_write_result(result) if result
    end

    def set_etag(etag)
      error = UplinkLib.uplink_part_upload_set_etag(@part_upload, etag)
      ErrorUtil.handle_error(error)
    ensure
      UplinkLib.uplink_free_error(error) if error
    end

    def commit
      error = UplinkLib.uplink_part_upload_commit(@part_upload)
      ErrorUtil.handle_error(error)
    ensure
      UplinkLib.uplink_free_error(error) if error
    end

    def abort
      error = UplinkLib.uplink_part_upload_abort(@part_upload)
      ErrorUtil.handle_error(error)
    ensure
      UplinkLib.uplink_free_error(error) if error
    end

    def info
      result = UplinkLib.uplink_part_upload_info(@part_upload)
      ErrorUtil.handle_result_error(result)

      UploadPart.new(result)
    ensure
      UplinkLib.uplink_free_part_result(result) if result
    end
  end

  class UploadPart
    attr_reader :part_number, :size, :modified, :etag

    def initialize(upload_part_result, upload_part = nil)
      init_attributes(upload_part_result.nil? || upload_part_result.null? ? upload_part : upload_part_result[:part])
    end

    private

    def init_attributes(part)
      return if part.nil? || part.null?

      @part_number = part[:part_number]
      @size = part[:size]
      @modified = part[:modified]
      @etag = part[:etag]
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
      @created, @expires, @content_length = UplinkUtil.get_system_values(object)
      @custom = UplinkUtil.get_custom_metadata(object)
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

  class UploadIterator
    def initialize(upload_iterator)
      @upload_iterator = upload_iterator
    end

    def next?
      has_next = UplinkLib.uplink_upload_iterator_next(@upload_iterator)
      unless has_next
        begin
          error = UplinkLib.uplink_upload_iterator_err(@upload_iterator)
          ErrorUtil.handle_error(error)
        ensure
          UplinkLib.uplink_free_error(error) if error
        end
      end

      has_next
    end

    def item
      upload_info = UplinkLib.uplink_upload_iterator_item(@upload_iterator)
      UploadInfo.new(nil, upload_info)
    ensure
      UplinkLib.uplink_free_upload_info(upload_info) if upload_info
    end
  end

  class UploadPartIterator
    def initialize(upload_part_iterator)
      @upload_part_iterator = upload_part_iterator
    end

    def next?
      has_next = UplinkLib.uplink_part_iterator_next(@upload_part_iterator)
      unless has_next
        begin
          error = UplinkLib.uplink_part_iterator_err(@upload_part_iterator)
          ErrorUtil.handle_error(error)
        ensure
          UplinkLib.uplink_free_error(error) if error
        end
      end

      has_next
    end

    def item
      upload_part = UplinkLib.uplink_part_iterator_item(@upload_part_iterator)
      UploadPart.new(nil, upload_part)
    ensure
      UplinkLib.uplink_free_part(upload_part) if upload_part
    end
  end

  class EdgeCredential
    attr_reader :access_key_id, :secret_key, :endpoint

    def initialize(edge_credentials_result, edge_credentials = nil)
      init_attributes(edge_credentials_result.nil? || edge_credentials_result.null? ? edge_credentials : edge_credentials_result[:credentials])
    end

    def join_share_url(base_url, bucket, key, options = nil)
      share_url_options = nil
      if options && !options.empty?
        share_url_options = UplinkLib::EdgeShareURLOptions.new
        share_url_options[:raw] = options[:raw]
      end

      result = UplinkLib.edge_join_share_url(base_url, @access_key_id, bucket, key, share_url_options)
      ErrorUtil.handle_result_error(result)

      result[:string]
    ensure
      UplinkLib.uplink_free_string_result(result) if result
    end

    private

    def init_attributes(edge_credentials)
      return if edge_credentials.nil? || edge_credentials.null?

      @access_key_id = edge_credentials[:access_key_id]
      @secret_key = edge_credentials[:secret_key]
      @endpoint = edge_credentials[:endpoint]
    end
  end

  class UplinkUtil
    class << self
      def get_system_values(object)
        return if object.null? || object[:system].null?

        [object[:system][:created], object[:system][:expires], object[:system][:content_length]]
      end

      def get_custom_metadata(object)
        custom = {}

        return custom if object.null? || object[:custom].null?

        count = object[:custom][:count]
        mem_entries = object[:custom][:entries]

        return custom if mem_entries.null?

        count.times do |i|
          entry = UplinkLib::UplinkCustomMetadataEntry.new(mem_entries + (i * UplinkLib::UplinkCustomMetadataEntry.size))
          next if entry.null?

          key = entry[:key].read_string
          value = entry[:value].read_string
          custom[key] = value
        end

        custom
      end

      def build_uplink_config(config)
        raise ArgumentError, 'config argument is nil' if config.nil?

        config_options = UplinkLib::UplinkConfig.new
        user_agent = FFI::MemoryPointer.from_string(config[:user_agent]) if config[:user_agent]
        temp_directory = FFI::MemoryPointer.from_string(config[:temp_directory]) if config[:temp_directory]
        config_options[:user_agent] = user_agent
        config_options[:dial_timeout_milliseconds] = config[:dial_timeout_milliseconds]&.to_i || 0
        config_options[:temp_directory] = temp_directory

        config_options
      end

      def build_upload_options(options)
        upload_options = nil
        if options && !options.empty?
          upload_options = UplinkLib::UplinkUploadOptions.new
          upload_options[:expires] = options[:expires].to_i if options[:expires]
        end

        upload_options
      end

      def build_custom_metadata(custom)
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

        custom_metadata
      end
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
