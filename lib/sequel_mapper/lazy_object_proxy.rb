require "delegate"

class LazyObjectProxy < SimpleDelegator
  def initialize(object_loader)
    @object_loader = object_loader
    @loaded = false
  end

  def method_missing(method_id, *args, &block)
    __load_object__

    super
  end

  def __getobj__
    __load_object__
    super
  end

  def loaded?
    !!@loaded
  end

  private

  def __load_object__
    __setobj__(@object_loader.call).tap {
      mark_as_loaded
    } unless loaded?
  end

  def mark_as_loaded
    @loaded = true
  end
end
