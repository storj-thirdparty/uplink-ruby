# frozen_string_literal: true

module Uplink
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
      register_config[:insecure_unencrypted_connection] = config[:insecure_unencrypted_connection]

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
end
