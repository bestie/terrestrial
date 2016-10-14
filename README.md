# Terrestrial

## TL;DR

* A Ruby ORM that enables DDD and clean architectural styles.
* Persists plain objects while supporting arbitrarily deeply nested / circular associations
* Provides excellent database and query building support courtesy of the [Sequel library](https://github.com/jeremyevans/sequel)

Terrestrial is a new, currently experimental [data mapper](http://martinfowler.com/eaaCatalog/dataMapper.html) ORM implementation for Ruby.

The aim is to provide a convenient way to query and persist graphs of Ruby objects (think models with associations), while keeping those object completely isolated and decoupled from the database.

In contrast to Ruby's many [active record](http://martinfowler.com/eaaCatalog/activeRecord.html) implementations, domain objects require no special inherited or mixed in behavior in order to be persisted.
In fact Terrestrial has no specific requirements for domain objects at all.
While there is a simple default, `.new` and `#to_h`, you may define arbitrary
functions (per mapping) and expose no reader methods at all.

## Features

* Absolute minimum coupling between domain and persistence
* Persistence of plain or arbitrary objects
* Associations (belongs_to, has_many, has_many_through)
* Automatic 'convention over configuration' that is fully customizable
* Lazy loading of associations
* Optional eager loading to avoid the `n + 1` query problem
* Dirty tracking for database write efficiency
* Predefined queries, scopes or subsets

There are some [conspicuous missing features](https://github.com/bestie/terrestrial/blob/master/MissingFeatures.md)
that you may want to read more about. If you want to contribute to solving any
of the problems listed please open an issue to discuss.

Terrestrial does not reinvent the wheel with querying abstraction and
migrations, instead these responsibilities are delegated to Sequel such that
its full power can be utilised.

For [querying](http://sequel.jeremyevans.net/rdoc/files/doc/querying_rdoc.html),
[migrations](http://sequel.jeremyevans.net/rdoc/files/doc/migration_rdoc.html)
and creating your [database connection](http://sequel.jeremyevans.net/rdoc/files/doc/opening_databases_rdoc.html)
see the Sequel documentation.

## Getting started

Please try this out, experiment, open issues and pull requests. Please read the
code of conduct first.

```ruby

  # 1. Define some domain objects, structs will surfice for the example

  User = Struct.new(:id, :first_name, :last_name, :email, :posts)
  Post = Struct.new(:id, :author, :subject, :body, :created_at, :categories)
  Category = Struct.new(:id, :name, :posts)

  ## Also assume that a conventional database schema (think Rails) is in place,
  ## a column for each of the struct's attributes will be present. The posts
  ## table will have `author_id` as a foreign key to the users table. There is
  ## a join table named `categories_to_posts` which facilitates the many to
  ## many relationship.

  # 2. Configure a Sequel database connection

  ## Terrestrial does not manage your connection for you.
  ## Example assumes Postgres however Sequel supports many other databases.

  DB = Sequel.postgres(
    host: ENV.fetch("PGHOST"),
    user: ENV.fetch("PGUSER"),
    database: ENV.fetch("PGDATABASE"),
  )

  # 3. Configure mappings and associations

  ## This is kept separate from your domain models as knowledge of the schema
  ## is required to wire them up.

  MAPPINGS = Terrestrial.config(DB)
    .setup_mapping(:users) { |users|
      users.class(User) # Specify a class and the constructor will be used
      users.has_many(:posts, foreign_key: :author_id)
    }
    .setup_mapping(:posts) { |posts|
      # To avoid directly specifiying a class, a factory function can be used instead
      posts.factory(->(attrs) { Post.new(attrs) })
      posts.belongs_to(:author, mapping_name: :users)
      posts.has_many_through(:categories)
    }
    .setup_mapping(:categories) { |categories|
      categories.class(Category)
      categories.has_many_through(:posts)
    }

  # 4. Create an object store by combining a connection and a configuration

  OBJECT_STORE = Terrestrial.object_store(
    datastore: DB,
    mappings: MAPPINGS,
  )

  ## You are not limted to one object store configuration or one database
  ## connection. To handle complex situations you may create several segregated
  ## mappings and object stores for your separate aggregate roots, potentially
  ## utilising multiple databases and different domain object
  ## classes/compositions.

  # 5. Create some objects

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

  # 6. Save them

  OBJECT_STORE[:users].save(user)

  ## Only the (aggregate) root object needs to be passed to the mapper.

  # 7. Query

  user = OBJECT_STORE[:users].where(id: "2f0f791c-47cf-4a00-8676-e582075bcd65").first

  # => #<struct User
  #  id="2f0f791c-47cf-4a00-8676-e582075bcd65",
  #  first_name="Stephen",
  #  last_name="Best",
  #  email="bestie@gmail.com",
  #  posts=#<Terrestrial::CollectionMutabilityProxy:7ff57192d510 >,

```

## Running the tests

### ENV vars

The test suite expects the following standard Postgres environment variables.

* PGHOST
* PGUSER
* PGDATABASE

### Create a test database

This will create a database named from the value of `PGDATABASE`

```
$ bundle exec rake db:create
```

### Run all tests RSpec and Cucumber

The RSpec tests run twice, once against Sequel/Postgres and again against
an in-memory datastore.

Cucumber runs only against the Sequel/Postgres backend.

```
$ bin/test
```

### Should anything go awry

Drop the test database and start fresh

```
$ bundle exec rake db:drop
```

## Installation

This library is still pre 1.0 so please lock down your version and update with
care.

Add the following to your `Gemfile`.

```
gem "terrestrial", "0.0.3"
```

And then execute:

    $ bundle

Or install it manually:

    $ gem install terrestrial

