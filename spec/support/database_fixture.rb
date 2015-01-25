require "support/mock_sequel"
require "sequel_mapper/struct_factory"

module SequelMapper
  module DatabaseFixture
    include SequelTestSupport

    # A little hack so these let blocks from an RSpec example don't have
    # to change
    def self.let(name, &block)
      define_method(name) {
        instance_variable_get("@#{name}") or
          instance_variable_set("@#{name}", instance_eval(&block))
      }
    end

    # TODO: perhaps split this file up

    # Domain objects (POROs)
    ::User = Struct.new(:id, :first_name, :last_name, :email, :posts, :toots)
    ::Post = Struct.new(:id, :author, :subject, :body, :comments, :categories)
    ::Comment = Struct.new(:id, :post, :commenter, :body)
    ::Category = Struct.new(:id, :name, :posts)
    ::Toot = Struct.new(:id, :tooter, :body, :tooted_at)

    # A factory per Struct
    # The factories serve two purposes
    #   1. Decouple the mapper from the actual class it instantiates so this can be changed at will
    #   2. The mapper has a hash of symbols => values and Stucts take positional arguments
    let(:user_factory){
      SequelMapper::StructFactory.new(User)
    }

    let(:post_factory){
      SequelMapper::StructFactory.new(Post)
    }

    let(:comment_factory){
      SequelMapper::StructFactory.new(Comment)
    }

    let(:category_factory){
      SequelMapper::StructFactory.new(Category)
    }

    let(:toot_factory){
      SequelMapper::StructFactory.new(Toot)
    }

    let(:datastore) {
      db_connection.tap { |db|
        # When using the standard fixutres we need the fixture data loaded
        # before the connection should be used
        load_fixture_data(db)

        # The query_counter will let us make assertions about how efficiently
        # the database is being used
        db.loggers << query_counter
      }
    }

    let(:query_counter) {
      SequelTestSupport::QueryCounter.new
    }

    def mapper_fixture
      SequelMapper.mapper(
        top_level_namespace: :users,
        datastore: datastore,
        mappings: mapper_config,
        dirty_map: DIRTY_MAP,
      )
    end

    def load_fixture_data(datastore)
      fixture_tables_hash.each do |table_name, rows|

        datastore.drop_table?(table_name)

        datastore.create_table(table_name) do
          # Create each column as a string type.
          # This will suffice for current tests.
          rows.first.keys.each do |column|
            String column
          end
        end

        rows.each do |row|
          datastore[table_name].insert(row)
        end
      end
    end

    # TODO: write something helpful about configuration.
    # Associations need not be two way but are setup symmetrically here for
    # illustrative purposes.

    require "sequel_mapper/mapping"
    require "sequel_mapper/identity_map"
    require "sequel_mapper/belongs_to_association_mapper"
    require "sequel_mapper/has_many_association_mapper"
    require "sequel_mapper/has_many_through_association_mapper"
    require "sequel_mapper/collection_mutability_proxy"
    require "sequel_mapper/queryable_lazy_dataset_loader"
    require "sequel_mapper/lazy_object_proxy"

    require "active_support/inflector"
    class Inflector
      include ActiveSupport::Inflector
    end

    INFLECTOR = Inflector.new
    DIRTY_MAP = {}

    class ConventionalAssociationConfigurator
      def initialize(mapping_name, mappings, dirty_map, datastore)
        @mapping_name = mapping_name
        @mappings = mappings
        @dirty_map = dirty_map
        @datastore = datastore
      end

      attr_reader :mapping_name, :mappings, :dirty_map, :datastore
      private     :mapping_name, :mappings, :dirty_map, :datastore

      DEFAULT = :use_convention

      def has_many(association_name, key: DEFAULT, foreign_key: DEFAULT, table_name: DEFAULT)
        defaults = {
          table_name: association_name,
          foreign_key: [INFLECTOR.singularize(mapping_name), "_id"].join.to_sym,
          key: :id,
        }
        specified = {
          table_name: table_name,
          foreign_key: foreign_key,
          key: key,
        }.reject { |_k,v|
          v == DEFAULT
        }

        config = defaults.merge(specified)
        config = config.merge(
            name: association_name,
            relation: datastore[config.fetch(:table_name)],
          )
        config.delete(:table_name)

        mappings.fetch(association_name).mark_foreign_key(config.fetch(:foreign_key))
        mappings[mapping_name].add_association(association_name, has_many_mapper(**config))
      end

      def belongs_to(association_name, key: DEFAULT, foreign_key: DEFAULT, table_name: DEFAULT)
        defaults = {
          key: :id,
          foreign_key: [association_name, "_id"].join.to_sym,
          table_name: INFLECTOR.pluralize(association_name).to_sym,
        }

        specified = {
          table_name: table_name,
          foreign_key: foreign_key,
          key: key,
        }.reject { |_k,v|
          v == DEFAULT
        }

        config = defaults
          .merge(specified)

        config.store(:name, config.fetch(:table_name))
        config.store(:relation, datastore[config.fetch(:table_name)])
        config.delete(:table_name)

        mappings.fetch(mapping_name).mark_foreign_key(config.fetch(:foreign_key))
        mappings[mapping_name].add_association(association_name, belongs_to_mapper(**config))
      end

      def has_many_through(association_name, key: DEFAULT, foreign_key: DEFAULT, table_name: DEFAULT, join_table_name: DEFAULT, association_foreign_key: DEFAULT)
        defaults = {
          table_name: association_name,
          foreign_key: [INFLECTOR.singularize(mapping_name), "_id"].join.to_sym,
          association_foreign_key: [INFLECTOR.singularize(association_name), "_id"].join.to_sym,
          join_table_name: [association_name, mapping_name].sort.join("_to_"),
          key: :id,
        }
        specified = {
          table_name: table_name,
          foreign_key: foreign_key,
          association_foreign_key: association_foreign_key,
          join_table_name: join_table_name,
          key: key,
        }.reject { |_k,v|
          v == DEFAULT
        }

        config = defaults.merge(specified)

        config = config
          .merge(
            name: association_name,
            relation: datastore[config.fetch(:table_name).to_sym],
            through_relation: datastore[config.fetch(:join_table_name).to_sym],
          )

        config.delete(:table_name)
        config.delete(:join_table_name)

        mappings[mapping_name].add_association(association_name, has_many_through_mapper(**config))
      end

      private

      def has_many_mapper(name:, relation:, key:, foreign_key:)
        HasManyAssociationMapper.new(
          foreign_key: foreign_key,
          key: key,
          relation: relation,
          mapping_name: name,
          dirty_map: dirty_map,
          proxy_factory: collection_proxy_factory,
          mappings: mappings,
        )
      end

      def belongs_to_mapper(name:, relation:, key:, foreign_key:)
        BelongsToAssociationMapper.new(
          foreign_key: foreign_key,
          key: key,
          relation: relation,
          mapping_name: name,
          dirty_map: dirty_map,
          proxy_factory: single_object_proxy_factory,
          mappings: mappings,
        )
      end

      def has_many_through_mapper(name:, relation:, through_relation:, key:, foreign_key:, association_foreign_key:)
        HasManyThroughAssociationMapper.new(
          foreign_key: foreign_key,
          association_foreign_key: association_foreign_key,
          key: key,
          relation: relation,
          through_relation: through_relation,
          mapping_name: name,
          dirty_map: dirty_map,
          proxy_factory: collection_proxy_factory,
          mappings: mappings,
        )
      end

      def single_object_proxy_factory
        LazyObjectProxy.method(:new)
      end

      def collection_proxy_factory
        ->(*args) {
          CollectionMutabilityProxy.new(
            QueryableLazyDatasetLoader.new(*args)
          )
        }
      end
    end

    class ConventionalConfigurator
      def initialize(datastore)
        @datastore = datastore
        @mappings = generate_mappings
      end

      attr_reader :datastore, :mappings
      private     :datastore, :mappings

      def [](mapping_name)
        mappings[mapping_name]
      end

      def for(table_name, &block)
        block.call(assocition_configurator(table_name)) if block
        self
      end

      private

      def assocition_configurator(table_name)
        ConventionalAssociationConfigurator.new(
          table_name,
          mappings,
          DIRTY_MAP,
          datastore,
        )
      end

      def generate_mappings
        Hash[
          tables
            .map { |table_name|
              [
                table_name,
                mapping(
                  fields: get_fields(table_name),
                  factory: table_name_to_factory(table_name),
                  associations: {},
                ),
              ]
            }
          ]
      end

      def get_fields(table_name)
        datastore[table_name]
          .columns
      end

      def table_name_to_factory(table_name)
        klass_name = INFLECTOR.classify(table_name)

        if Object.constants.include?(klass_name.to_sym)
          klass = Object.const_get(klass_name)
          if klass.ancestors.include?(Struct)
            StructFactory.new(klass)
          else
            klass.method(:new)
          end
        else
          warn "WARNDING: Class not found for table #{table_name}"
        end
      end

      def tables
        (datastore.tables - [:schema_migrations])
      end

      def dirty_map
        DIRTY_MAP
      end

      def mapping(**args)
        IdentityMap.new(
          Mapping.new(**args)
        )
      end

    end

    let(:mapper_config) {
      ConventionalConfigurator
        .new(datastore)
        .for(:users) do |config|
          config.has_many(:posts, foreign_key: :author_id)
          config.has_many(:toots, foreign_key: :tooter_id)
        end
        .for(:posts) do |config|
          config.belongs_to(:author, table_name: :users)
          config.has_many(:comments)
          config.has_many_through(:categories)
        end
        .for(:comments) do |config|
          config.belongs_to(:post)
          config.belongs_to(:commenter, table_name: :users)
        end
        .for(:categories) do |config|
          config.has_many_through(:posts)
        end
        .for(:toots) do |config|
          config.belongs_to(:tooter, table_name: :users)
        end
    }

    # This hash represents the data structure that will be written to
    # the database.
    let(:fixture_tables_hash) {
      {
        users: [
          user_1_data,
          user_2_data,
          user_3_data,
        ],
        posts: [
          post_1_data,
          post_2_data,
        ],
        comments: [
          comment_1_data,
          comment_2_data,
          comment_3_data,
        ],
        categories: [
          category_1_data,
          category_2_data,
        ],
        categories_to_posts: [
          {
            post_id: post_1_data.fetch(:id),
            category_id: category_1_data.fetch(:id),
          },
          {
            post_id: post_1_data.fetch(:id),
            category_id: category_2_data.fetch(:id),
          },
          {
            post_id: post_2_data.fetch(:id),
            category_id: category_2_data.fetch(:id),
          },
        ],
        toots: [
          # Toot ordering is inconsistent for scope testing.
          toot_2_data,
          toot_1_data,
          toot_3_data,
        ],
      }
    }

    let(:user_1_data) {
      {
        id: "user/1",
        first_name: "Stephen",
        last_name: "Best",
        email: "bestie@gmail.com",
      }
    }

    let(:user_2_data) {
      {
        id: "user/2",
        first_name: "Hansel",
        last_name: "Trickett",
        email: "hansel@gmail.com",
      }
    }

    let(:user_3_data) {
      {
        id: "user/3",
        first_name: "Jasper",
        last_name: "Trickett",
        email: "jasper@gmail.com",
      }
    }

    let(:post_1_data) {
      {
        id: "post/1",
        author_id: "user/1",
        subject: "Object mapping",
        body: "It is often tricky",
      }
    }

    let(:post_2_data) {
      {
        id: "post/2",
        author_id: "user/1",
        subject: "Object mapping part 2",
        body: "Lazy load all the things!",
      }
    }

    let(:comment_1_data) {
      {
        id: "comment/1",
        post_id: "post/1",
        commenter_id: "user/2",
        body: "Trololol",
      }
    }

    let(:comment_2_data) {
      {
        id: "comment/2",
        post_id: "post/1",
        commenter_id: "user/1",
        body: "You are so LOL",
      }
    }

    let(:comment_3_data) {
      {
        id: "comment/3",
        post_id: "post/2",
        commenter_id: "user/3",
        body: "I am trolling",
      }
    }

    let(:category_1_data) {
      {
        id: "category/1",
        name: "good",
      }
    }

    let(:category_2_data) {
      {
        id: "category/2",
        name: "bad",
      }
    }

    let(:category_3_data) {
      {
        id: "category/3",
        name: "ugly",
      }
    }

    let(:toot_1_data) {
      {
        id: "toot/1",
        tooter_id: "user/1",
        body: "Armistice toots",
        tooted_at: Time.parse("2014-11-11 11:11:00 UTC").iso8601,
      }
    }
    let(:toot_2_data) {
      {
        id: "toot/2",
        tooter_id: "user/1",
        body: "Tooting every second",
        tooted_at: Time.parse("2014-11-11 11:11:01 UTC").iso8601,
      }
    }

    let(:toot_3_data) {
      {
        id: "toot/3",
        tooter_id: "user/1",
        body: "Join me in a minutes' toots",
        tooted_at: Time.parse("2014-11-11 11:11:02 UTC").iso8601,
      }
    }
  end
end
