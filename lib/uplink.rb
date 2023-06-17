# frozen_string_literal: true

require 'uplink_lib'
require 'uplink/access'
require 'uplink/bucket'
require 'uplink/download'
require 'uplink/edge_credential'
require 'uplink/error_util'
require 'uplink/object'
require 'uplink/project'
require 'uplink/storj_error'
require 'uplink/uplink_util'
require 'uplink/upload'

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
end
