module SequelMapper
  module FlatMapExpandable
    def flat_map(&block)
      map(&block)
        .map { |node|
          node.respond_to?(:flat_map_expand, true) ?
            node.flat_map_expand :
            node
        }
        .flatten(1)
    end

    protected

    def flat_map_expand
      to_a
    end
  end
end
