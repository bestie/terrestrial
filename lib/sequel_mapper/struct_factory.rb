module Terrestrial
  class StructFactory
    def initialize(struct_class)
      @constructor = struct_class.method(:new)
      @members = struct_class.members
    end

    attr_reader :constructor, :members
    private     :constructor, :members

    def call(data)
      constructor.call(
        *members.map { |m| data.fetch(m, nil) }
      )
    end
  end
end
