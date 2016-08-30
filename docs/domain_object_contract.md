# Domain object contract

## Configurable defaults

For saving a new or updating an existing object, Terrestrial assumes that your
domain objects implement a `#to_h` method that returns a Hash (keyed with
Symbols) of attributes that can be directly inserted into the database.

The `#to_h` interface is common in Ruby, `Struct` and `OpenStruct` both
implement this behavior as standard.

*This is the only method terrestrial will ever call on your objects*

For loading previously persisted objects, Terrestrial assumes that your domain
objects can be instantiated by calling `.new` on the specified or inferred
class with a Hash (keyed with Symbols) of attributes that match the database
column names.

This attributes Hash into constructor interface is supported by `OpenStruct`
but not by `Struct`. Terrestrial will treats `Struct` as a special case and
translates attributes into an ordered array of values. See `Terrestrial::StructAdapter`

## Custom serializers and factories

If you prefer Terrestrial not to call any methods on your domain objects this
is absolutely possible and encouraged.

A serializer function should be a lambda like object capable of converting a
domain object into a Hash (keyed by Symbols) and its persistable values.

For the default scenario detailed above Terrestrial generates the following
lambda.

```ruby
  ->(domain_object) { domain_object.to_h }
```

A factory lambda will be called with same Hash of Symbol to value as above.

The default configuration would generate something like this for a users mapping.

```ruby
  ->(attributes_hash) { User.new(attributes_hash) }
```

Providing bespoke functions can achieve many goals including:
  * Looser coupling to Terrestrial
  * Translation, modification or decoration of incoming and outgoing data
  * Dynamically select a class (like Rails STI that doesn't necessarily need
    inheritance)
