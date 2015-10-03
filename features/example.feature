Feature: Basic setup

  Scenario: Setup with conventional configuration
    Given the domain objects are defined
      """
        User = Struct.new(:id, :first_name, :last_name, :email, :posts)
        Post = Struct.new(:id, :author, :subject, :body, :categories)
        Category = Struct.new(:id, :name, :posts)
      """
    And a conventionally similar database schema for table "users"
      """
        Column      | Type
       ------------ +---------
        id          | text
        first_name  | text
        last_name   | text
        email       | text
      """
    And a conventionally similar database schema for table "posts"
      """
        Column      | Type
       -------------+---------
        id          | text
        author_id   | text
        subject     | text
        body        | text
      """
    And a conventionally similar database schema for table "categories"
      """
        Column      | Type
       -------------+---------
        id          | text
        name        | text
      """
    And a conventionally similar database schema for table "categories_to_posts"
      """
        Column      | Type
       -------------+---------
        post_id     | text
        category_id | text
      """
    And a database connection is established
      """
        DB = Sequel.postgres(
          host: ENV.fetch("PGHOST"),
          user: ENV.fetch("PGUSER"),
          database: ENV.fetch("PGDATABASE"),
        )
      """
    And the associations are defined in the mapper configuration
      """
      USER_MAPPER_CONFIG = SequelMapper.config(DB)
        .setup_mapping(:users) { |users|
          users.has_many(:posts, foreign_key: :author_id)
        }
        .setup_mapping(:posts) { |posts|
          posts.belongs_to(:author, mapping_name: :users)
          posts.has_many_through(:categories)
        }
        .setup_mapping(:categories) { |categories|
          categories.has_many_through(:posts)
        }
      """
    And a mapper is instantiated
      """
        USER_MAPPER = SequelMapper.mapper(
          datastore: DB,
          config: USER_MAPPER_CONFIG,
          name: :users,
        )
      """
    When a new graph of objects are created
      """
        user = User.new(
          "2f0f791c-47cf-4a00-8676-e582075bcd65",
          "Hansel",
          "Trickett",
          "hansel@tricketts.org",
          [],
        )

        user.posts << Post.new(
          "9b75fe2b-d694-4b90-9137-6201d426dda2",
          nil,
          "Things that I like",
          "I like fish and scratching",
          [],
        )
      """
    And the new graph is saved
      """
        USER_MAPPER.save(user)
      """
    And the following query is executed
      """
        user = USER_MAPPER.where(id: "2f0f791c-47cf-4a00-8676-e582075bcd65").first
      """
    Then the persisted user object is returned with lazy associations
      """
        #<struct User id="2f0f791c-47cf-4a00-8676-e582075bcd65",
          first_name="Hansel",
          last_name="Trickett",
          email="hansel@tricketts.org",
          posts=#<SequelMapper::CollectionMutabilityProxy:7fa4817aa148
        >>
      """
    And the user's posts will be loaded once the association proxy receives an Enumerable message
      """
        [#<struct Post id="9b75fe2b-d694-4b90-9137-6201d426dda2",
          author=#<SequelMapper::LazyObjectProxy:7fc9a4989958 known_fields={:id=>"2f0f791c-47cf-4a00-8676-e582075bcd65"} lazy_object=nil>,
          subject="Things that I like",
          body="I like fish and scratching",
          categories=#<SequelMapper::CollectionMutabilityProxy:7fc9a4988b20
        >>]
      """
