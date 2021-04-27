module Terrestrial
  # TODO: This should do a better job of showing what will be loaded when it is inspected
  class LazyObjectProxy
    include InspectionString

    def initialize(object_loader, key_fields)
      @object_loader = object_loader
      @key_fields = key_fields
      @lazy_object = nil
    end

    attr_reader :object_loader
    private     :object_loader

    def method_missing(method_id, *args, &block)
      if args.empty? && __key_fields.include?(method_id)
        __key_fields.fetch(method_id)
      else
        lazy_object.public_send(method_id, *args, &block)
      end
    end

    def loaded?
      !!@lazy_object
    end

    def __getobj__
      lazy_object
    end

    def each_loaded(&block)
      [self].each(&block)
    end

    def __key_fields
      @key_fields
    end

    private

    def respond_to_missing?(method_id, _include_private = false)
      __key_fields.include?(method_id) || lazy_object.respond_to?(method_id)
    end

    def lazy_object
      @lazy_object ||= object_loader.call
    end

    def inspectable_properties
      [
        :key_fields,
        :lazy_object,
      ]
    end
  end
end
