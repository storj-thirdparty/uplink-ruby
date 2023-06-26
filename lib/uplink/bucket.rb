# frozen_string_literal: true

module Uplink
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
end
