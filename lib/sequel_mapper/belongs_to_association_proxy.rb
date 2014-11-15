require "delegate"

class BelongsToAssociationProxy < SimpleDelegator
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

  private

  def __load_object__
    __setobj__(@object_loader.call).tap {
      @loaded = true
    } unless @loaded
  end
end
