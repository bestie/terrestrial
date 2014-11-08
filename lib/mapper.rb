class Mapper
  def initialize(datastore:, top_level_namespace:, relation_mappings:)
    @top_level_namespace = top_level_namespace
    @datastore = datastore
    @relation_mappings = relation_mappings
  end

  attr_reader :top_level_namespace, :datastore, :relation_mappings
  private     :top_level_namespace, :datastore, :relation_mappings

  def where(criteria)
    datastore[top_level_namespace]
      .where(criteria)
      .map { |row| load(relation_mappings.fetch(:users), row) }
  end

  private

  def load(relation, row)
    has_many_associations = Hash[
      relation.fetch(:has_many, []).map { |assoc_name, assoc|
        [
          assoc_name,
          datastore[assoc.fetch(:relation_name)]
            .where(assoc.fetch(:foreign_key) => row.fetch(:id))
            .map { |row|
              load(relation_mappings.fetch(assoc.fetch(:relation_name)), row)
            }
        ]
      }
    ]

    relation.fetch(:factory).call(row.merge(has_many_associations))
  end

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

  class MockSequel
    def initialize(relations)
      @relations = relations
    end

    def [](table_name)
      Relation.new(@relations.fetch(table_name))
    end

    class Relation
      include Enumerable

      def initialize(rows)
        @rows = rows
      end

      def where(criteria, &block)
        if block
          raise NotImplementedError.new("Block filtering not implemented")
        end

        self.class.new(equality_filter(criteria))
      end

      def to_a
        @rows
      end

      def each(&block)
        to_a.each(&block)
      end

      private

      def equality_filter(criteria)
        @rows.select { |row|
          criteria.all? { |k, v|
            row.fetch(k) == v
          }
        }
      end
    end
  end
end

