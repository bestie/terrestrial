require "delegate"

class LazyObjectProxy
  def initialize(object_loader, known_fields)
    @object_loader = object_loader
    @known_fields = known_fields
    @lazy_object = nil
  end

  attr_reader :object_loader, :known_fields
  private     :object_loader, :known_fields

  def method_missing(method_id, *args, &block)
    if args.empty? && known_fields.include?(method_id)
      known_fields.fetch(method_id)
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

  private

  def respond_to_missing?(method_id, _include_private = false)
    known_fields.include?(method_id) || lazy_object.respond_to?(method_id)
  end

  def lazy_object
    @lazy_object ||= object_loader.call
  end
end
