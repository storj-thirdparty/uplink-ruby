# frozen_string_literal: true

module Uplink
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
end
