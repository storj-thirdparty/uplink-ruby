# frozen_string_literal: true

module Uplink
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
end
