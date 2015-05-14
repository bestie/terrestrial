module SequelMapper
  module AssociationLoaders
    class OneToMany
      def initialize(type:, mapping_name:, foreign_key:, key:, proxy_factory:)
        @type = type
        @mapping_name = mapping_name
        @foreign_key = foreign_key
        @key = key
        @proxy_factory = proxy_factory
        @eager_loads = {}
      end

      attr_reader :type, :mapping_name, :foreign_key, :key, :proxy_factory
      private     :type, :mapping_name, :foreign_key, :key, :proxy_factory

      def fetch(*args, &block)
        {
          key: key,
          foreign_key: foreign_key,
          type: type,
          mapping_name: mapping_name,
        }.fetch(*args, &block)
      end

      def call(mappings, record, &object_pipeline)
        mapping = mappings.fetch(mapping_name)

        proxy_factory.call(
          query: query(mapping, record),
          loader: object_pipeline.call(mapping),
          association_loader: self,
        )
      end

      def query(mapping, record)
        foreign_key_value = record.fetch(key)

        ->(datastore) {
          @eager_loads.fetch(record) {
            datastore[mapping.namespace]
              .where(foreign_key => foreign_key_value)
          }
        }
      end

      def eager_load(dataset, association_name)
        datastore[mapping.namespace]
          .where(foreign_key => dataset.select(key))
      end
    end
  end
end
