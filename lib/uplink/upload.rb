# frozen_string_literal: true

module Uplink
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
end
