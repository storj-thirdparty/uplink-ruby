# frozen_string_literal: true

module Uplink
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
end
