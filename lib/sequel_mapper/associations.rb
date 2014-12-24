require "sequel_mapper/belongs_to_association_proxy"
require "sequel_mapper/association_proxy"

module SequelMapper
  module Associations
    class Association
      def initialize(datastore:, mappings:, mapping:)
        @datastore = datastore
        @mappings = mappings
        @mapping_name = mapping
      end

      attr_reader :datastore, :mapping

      def load(_row)
        raise NotImplementedError
      end

      def mapping
        @mappings.fetch(@mapping_name)
      end

      private

      def relation_name
        mapping.relation_name
      end
    end

    class BelongsTo < Association
      def initialize(foreign_key:, **args)
        @foreign_key = foreign_key
        super(**args)
      end

      attr_reader :foreign_key
      private     :foreign_key

      def load(row)
        BelongsToAssociationProxy.new(
          datastore[relation_name]
            .where(:id => row.fetch(foreign_key))
            .lazy
            .map { |row|
              mapping.load(row)
            }
            .public_method(:first)
        )
      end
    end

    class HasMany < Association
      def initialize(key:, foreign_key:, order_by: [], **args)
        @key = key
        @foreign_key = foreign_key
        super(**args)
      end

      attr_reader :key, :foreign_key
      private     :key, :foreign_key

      def load(row)
        data_enum = datastore[relation_name]
          .where(foreign_key => row.fetch(key))

        AssociationProxy.new(
          data_enum
            .lazy
            .map { |row|
              mapping.load(row)
            }
        )
      end
    end

    class HasManyThrough < Association
      def initialize(through_relation_name:, foreign_key:, association_foreign_key:, **args)
        @through_relation_name = through_relation_name
        @foreign_key = foreign_key
        @association_foreign_key = association_foreign_key
        super(**args)
      end

      attr_reader :through_relation_name, :foreign_key, :association_foreign_key
      private     :through_relation_name, :foreign_key, :association_foreign_key

      def load(row)
        AssociationProxy.new(
          datastore[relation_name]
            .join(through_relation_name, association_foreign_key => :id)
            .where(foreign_key => row.fetch(:id))
            .lazy
            .map { |row|
              mapping.load(row)
            }
        )
      end
# 
#         private
# 
#         def value_columns
#           mapping.fields
#         end
    end
  end
end
