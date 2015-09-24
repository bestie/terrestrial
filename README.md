# SequelMapper

## TL;DR

* A Ruby ORM that enables DDD and clean architectural styles.
* Persists plain objects while supporting arbitrarily deeply nested / circular associations
* Provides excellent database and query building support via the excellent [Sequel library](https://github.com/jeremyevans/sequel) and so has excellent database support and query building options.

## What is it?

SequelMapper (working title) is a new, currently experimental [data mapper](http://martinfowler.com/eaaCatalog/dataMapper.html) implementation for Ruby.
Put simply it takes data from a database and populates your objects with it while keeping them both isolated from one another.
In contrast to Ruby's many [active record](http://martinfowler.com/eaaCatalog/activeRecord.html) implementations, domain objects can be free from persistence concerns and require no special inherited or mixed in behavior in order to be persisted.

Features include:
* Associations (belongs_to, has_many, has_many_through)
* Automatic 'convention over configuration' that is fully customizable
* Lazy loading for database read efficiency
* Dirty tracking for database write efficiency

The initial version is built on top of Jeremy Evans' [Sequel library](https://github.com/jeremyevans/sequel) and so has excellent database support and query building options.

## Why is it?

Since reading and hearing about Uncle Bob's clean architecture and Matt Wynne's
hexagonal Rails I have dedicated a lot of time to building applications with
this philosophy and honing the tricks and techniques that make them effective.

Unfortunately Ruby's lack of persistence options means that truly achieving the
goals of the clean architectural style is rather difficult and have on more
than one occasion resorted to implementing my own (simple) data mappers.

Of course this approach falls down extremely quickly when you have a complex
data model and/or a deep object graph.

## A quick example

```ruby

  # Some structs

  User = Struct.new(:id, :name, :email, :posts)
  Post = Struct.new(:id, :author, :subject, :body)

  # Configure a Sequel database connection (you may already have one)

  database = Sequel.postgres(
    host: ENV.fetch("PGHOST"),
    user: ENV.fetch("PGUSER"),
    database: ENV.fetch("PGDATABASE"),
  )

  # Configure mappings and associations separately

  mapper_config = SequelMapper.config(database)
    .setup_mapping(:users) do |config|
      config.has_many(:posts, foreign_key: :author_id)
    end
    .setup_mapping(:posts) do |config|
      config.belongs_to(:author, mapping_name: :users)
      config.has_many_through(:categories)
    end
    .setup_mapping(:categories) do |config|
      config.has_many_through(:posts)
    end

  # Create a mapper by combining a connection and a configuration

  user_mapper = SequelMapper.mapper(
    datastore: database,
    config: mapper_config,
    name: :users,
  )

  # We want to get a user by their ID

  user = user_mapper.where(id: "2f0f791c-47cf-4a00-8676-e582075bcd65").first
  # => #<struct User
  #  id="2f0f791c-47cf-4a00-8676-e582075bcd65",
  #  first_name="Stephen",
  #  last_name="Best",
  #  email="bestie@gmail.com",
  #  posts=#<SequelMapper::CollectionMutabilityProxy:7ff57192d510 >,

  # And access their posts

  user.posts
  # => #<SequelMapper::CollectionMutabilityProxy:7ff57192d510 >
  # That's lazily evaluated try ...

  user.posts.to_a
  # => [#<struct Post
  #   id="9b75fe2b-d694-4b90-9137-6201d426dda2",
  #   author=
  #    #<struct User
  #     id="2f0f791c-47cf-4a00-8676-e582075bcd65",
  #     first_name="Stephen",
  #     last_name="Best",
  #     email="bestie@gmail.com",
  #     posts=#<SequelMapper::CollectionMutabilityProxy:7ff57192d510 >,
  #   subject="Object mapping",
  #   body="It is often tricky",
  #   comments=#<SequelMapper::CollectionMutabilityProxy:7ff571ccadf8 >,
  #   categories=#<SequelMapper::CollectionMutabilityProxy:7ff571cca678 >>,
  #  #<struct Post
  #   id="bd564cc0-b8f1-45e6-9287-1ae75878c665",
  #   author=
  #    #<struct User
  #     id="2f0f791c-47cf-4a00-8676-e582075bcd65",
  #     first_name="Stephen",
  #     last_name="Best",
  #     email="bestie@gmail.com",
  #     posts=#<SequelMapper::CollectionMutabilityProxy:7ff57192d510 >,
  #   subject="Object mapping part 2",
  #   body="Lazy load all the things!",
  #   comments=#<SequelMapper::CollectionMutabilityProxy:7ff571cc9f48 >,
  #   categories=#<SequelMapper::CollectionMutabilityProxy:7ff571cc97c8 >>]

  # We can go around in circles traversing the object graph

  post = user.posts.first.categories.first.posts.first
  # => #<struct Post id="9b75fe2b-d694-4b90-9137-6201d426dda2", ...

  # Now make some changes

  new_post = Post.new(3, user, "Examples are hard", "BODY", [], [])
  user.posts.push(new_post)

  user.posts.first.subject = "I didn't like how it was before"

  user.email = "new_email@gmail.com"

  # Several changes have now been made and all we need to do is hand back to
  # mapper the object it originally gave us (the root node of the graph) and
  # all changes will be persisted.

  user_mapper.save(user)
```

## More detailled example

```ruby
  # Starting with a simple and familiar data model of users, blog posts and categories
  # we can first define our domain objects and start to experiment with them.

  User = Struct.new(:id, :first_name, :last_name, :email, :posts)
  Post = Struct.new(:id, :author, :subject, :body, :comments, :categories)
  Comment = Struct.new(:id, :post, :commenter, :body)
  Category = Struct.new(:id, :name, :posts)

  # Later when we decide this looks correct we can create some tables

  #  users:
  #     Column   | Type    | Modifiers
  #  ------------+---------+-----------
  #   id         | integer | not null
  #   first_name | text    |
  #   last_name  | text    |
  #   email      | text    |
  #
  #  posts:
  #    Column   | Type    | Modifiers
  #  -----------+---------+-----------
  #   id        | integer | not null
  #   author_id | text    |
  #   subject   | text    |
  #   body      | text    |
  #
  #  categories:
  #   Column | Type    | Modifiers
  #  --------+---------+-----------
  #   id     | integer | not null
  #   name   | text    |
  #
  #  categories_posts:
  #     Column    | Type    | Modifiers
  #  -------------+---------+--------
  #   post_id     | integer | not null
  #   category_id | integer | not null

  # Next we create a database connection

  database = Sequel.postgres(
    host: ENV.fetch("PGHOST"),
    user: ENV.fetch("PGUSER"),
    database: ENV.fetch("PGDATABASE"),
  )

  # SequelMapper follows the philosphy of convention over configuration, while
  # allowing anything to be overriden. Only a minimal amount of boiler plate is
  # required to wire up our associations. These must be defined here separately
  # from the objects themselves so they remain clean and simple.
  #
  # Configuration is completely separate from the SequelMapper's core so it
  # would be possible to scrape all this metadata from your objects should you
  # wish to implement it.
  #
  # Many things can be configured here including class, factory function, table
  # name, queries (scopes) and serialization, here only the minimum is shown.

  mapper_config = SequelMapper.config(database)
    .setup_mapping(:users) do |config|
      config.has_many(:posts, foreign_key: :author_id)
    end
    .setup_mapping(:posts) do |config|
      config.belongs_to(:author, mapping_name: :users)
      config.has_many(:comments)
      config.has_many_through(:categories)
    end
    .setup_mapping(:comments) do |config|
      config.belongs_to(:post)
      config.belongs_to(:commenter, mapping_name: :users)
    end
    .setup_mapping(:categories) do |config|
      config.has_many_through(:posts)
    end

  # Finally we create our user mapper, passing it the database connection,
  # config and the name of the mapping we'd like it to expose.

  user_mapper = SequelMapper.mapper(
    datastore: database,
    config: mapper_config,
    name: :users,
  )

  # This would be perfect for when a user is authenticated and editing their
  # blog posts. When a public page is viewed we may want a post_mapper which
  # may or may not share the same config and database. A read slave database
  # connection or config that returns immuatable objects may be desirable.

  # We may want to find a user by their id

  user = user_mapper.where(id: "2f0f791c-47cf-4a00-8676-e582075bcd65").first
  # => #<struct User
  #  id="2f0f791c-47cf-4a00-8676-e582075bcd65",
  #  first_name="Stephen",
  #  last_name="Best",
  #  email="bestie@gmail.com",
  #  posts=#<SequelMapper::CollectionMutabilityProxy:7ff57192d510 >,

  user.posts
  # => #<SequelMapper::CollectionMutabilityProxy:7ff57192d510 >
  # That's lazily evaluated try ...

  user.posts.to_a
  # => [#<struct Post
  #   id="9b75fe2b-d694-4b90-9137-6201d426dda2",
  #   author=
  #    #<struct User
  #     id="2f0f791c-47cf-4a00-8676-e582075bcd65",
  #     first_name="Stephen",
  #     last_name="Best",
  #     email="bestie@gmail.com",
  #     posts=#<SequelMapper::CollectionMutabilityProxy:7ff57192d510 >,
  #   subject="Object mapping",
  #   body="It is often tricky",
  #   comments=#<SequelMapper::CollectionMutabilityProxy:7ff571ccadf8 >,
  #   categories=#<SequelMapper::CollectionMutabilityProxy:7ff571cca678 >>,
  #  #<struct Post
  #   id="bd564cc0-b8f1-45e6-9287-1ae75878c665",
  #   author=
  #    #<struct User
  #     id="2f0f791c-47cf-4a00-8676-e582075bcd65",
  #     first_name="Stephen",
  #     last_name="Best",
  #     email="bestie@gmail.com",
  #     posts=#<SequelMapper::CollectionMutabilityProxy:7ff57192d510 >,
  #   subject="Object mapping part 2",
  #   body="Lazy load all the things!",
  #   comments=#<SequelMapper::CollectionMutabilityProxy:7ff571cc9f48 >,
  #   categories=#<SequelMapper::CollectionMutabilityProxy:7ff571cc97c8 >>]

  # We can go around in circles traversing the object graph

  post = user.posts.first.categories.first.posts.first
  # => #<struct Post id="9b75fe2b-d694-4b90-9137-6201d426dda2", ...

  # Now make some changes

  new_post = Post.new(3, user, "Examples are hard", "BODY", [], [])
  user.posts.push(new_post)

  user.posts.first.subject = "I didn't like how it was before"

  user.email = "new_email@gmail.com"

  # Several changes have now been made and all we need to do is hand back to
  # mapper the object it originally gave us (the root node of the graph) and
  # all changes will be persisted.

  user_mapper.save(user)
```

## Running the tests

### Set the following environment variables
* PGHOST
* PGUSER
* PGDATABASE

### Create the database and standard (blog) schema
```
$ bundle exec rake db:setup
```

### Run RSpec
```
$ bundle exec rspec
```

### Drop the test database and start fresh
```
$ bundle exec rake db:drop
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sequel_mapper'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sequel_mapper

