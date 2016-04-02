Feature: Basic setup

  Scenario: Setup with conventional configuration
    Given the domain objects are defined
      """
        User = Struct.new(:id, :first_name, :last_name, :email, :posts)
        Post = Struct.new(:id, :author, :subject, :body, :created_at, :categories)
        Category = Struct.new(:id, :name, :posts)
      """
    And a conventionally similar database schema for table "users"
      """
        Column      | Type
       ------------ +---------
        id          | String
        first_name  | String
        last_name   | String
        email       | String
      """
    And a conventionally similar database schema for table "posts"
      """
        Column      | Type
       -------------+---------
        id          | String
        author_id   | String
        subject     | String
        body        | String
        created_at  | DateTime
      """
    And a conventionally similar database schema for table "categories"
      """
        Column      | Type
       -------------+---------
        id          | String
        name        | String
      """
    And a conventionally similar database schema for table "categories_to_posts"
      """
        Column      | Type
       -------------+---------
        post_id     | String
        category_id | String
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
      MAPPINGS_CONFIG = Terrestrial.config(DB)
        .setup_mapping(:users) { |users|
          users.class(User)
          users.has_many(:posts, foreign_key: :author_id)
        }
        .setup_mapping(:posts) { |posts|
          posts.class(Post)
          posts.belongs_to(:author, mapping_name: :users)
          posts.has_many_through(:categories)
        }
        .setup_mapping(:categories) { |categories|
          categories.class(Category)
          categories.has_many_through(:posts)
        }
      """
    And a mapper is instantiated
      """
        MAPPERS = Terrestrial.mappers(
          datastore: DB,
          mappings: MAPPINGS_CONFIG,
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
          user,
          "Things that I like",
          "I like fish and scratching",
          Time.parse("2015-10-03 21:00:00 UTC"),
          [],
        )
      """
    And the new graph is saved
      """
        MAPPERS[:users].save(user)
      """
    And the following query is executed
      """
        user = MAPPERS[:users].where(id: "2f0f791c-47cf-4a00-8676-e582075bcd65").first
      """
    Then the persisted user object is returned with lazy associations
      """
        #<struct User id="2f0f791c-47cf-4a00-8676-e582075bcd65",
          first_name="Hansel",
          last_name="Trickett",
          email="hansel@tricketts.org",
          posts=#<Terrestrial::CollectionMutabilityProxy:7fa4817aa148
        >>
      """
    And the user's posts will be loaded once the association proxy receives an Enumerable message
      """
        [#<struct Post id="9b75fe2b-d694-4b90-9137-6201d426dda2",
          author=#<Terrestrial::LazyObjectProxy:7fec5ac2a5f8 key_fields={:id=>"2f0f791c-47cf-4a00-8676-e582075bcd65"} lazy_object=nil>,
          subject="Things that I like",
          body="I like fish and scratching",
          created_at=2015-10-03 21:00:00 UTC,
          categories=#<Terrestrial::CollectionMutabilityProxy:7fec5ac296f8
        >>]
      """
