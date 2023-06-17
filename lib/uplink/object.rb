# frozen_string_literal: true

module Uplink
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
end
