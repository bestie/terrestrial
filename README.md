# SequelMapper

**Very new, much experimental, so incomplete**

## What it is

It's a data mapper that allows you to map rows from a database into a graph of
plain ruby objects with arbitrary depth. The graph can then be manipulated and
persisted back into the database.

The main feature is that it fully supports all the kinds of data associations
that you are used to with ActiveRecord.

It is built on top of Jeremy Evans' Sequel library.

## Why is it?

* It seems like ROM may not be finished any time soon and I felt I could put
  together something functional albeit less ambitious
* I love the Sequel library
* I love decoupling persistence
* Writing a complex datamapper is sure way to stall your project so I'm writing
  one for you
* I am a sick person who enjoys this sort of thing

So go on, persist those POROs, they don't even have to know about it.

## Example

```ruby
  # Let's say you have some domain objects
  User = Struct.new(:id, :first_name, :last_name, :email, :posts)
  Post = Struct.new(:id, :author, :subject, :body, :comments, :categories)
  Comment = Struct.new(:id, :post, :commenter, :body)
  Category = Struct.new(:id, :name, :posts)

  # And a database with some tables that look similar

  # Then this may appeal to you

  user = user_mapper.where(id: 1).first
  # => [#<struct User
  #       id=1,
  #       first_name="Stephen",
  #       last_name="Best",
  #       email="bestie@gmail.com",
  #       posts=#<SequelMapper::AssociationProxy:0x007ffbc3c7cb50 @assoc_enum=#<Enumerator::Lazy: ...>, @removed_nodes=[]>>]

  user.posts
  # => #<SequelMapper::AssociationProxy:0x007ffbc3c7cb50 @assoc_enum=#<Enumerator::Lazy: ...>, @removed_nodes=[]>
  # That's lazily evaluated try ...

  user.posts.to_a
  # => [#<struct Post
  #       id=1,
  #       author=
  #        #<struct User
  #         id=1,
  #         first_name="Stephen",
  #         last_name="Best",
  #         email="bestie@gmail.com",
  #         posts=#<SequelMapper::AssociationProxy:0x007ffbc3c7cb50 @assoc_enum=#<Enumerator::Lazy: ...>, @removed_nodes=[]>>,
  #       subject="Object mapping",
  #       body="It is often tricky",
  #       comments=#<SequelMapper::AssociationProxy:0x007ffbc59377b8 @assoc_enum=#<Enumerator::Lazy: ...>, @removed_nodes=[]>,
  #       categories=#<SequelMapper::AssociationProxy:0x007ffbc5936138 @assoc_enum=#<Enumerator::Lazy: ...>, @removed_nodes=[]>>,
  #      #<struct Post
  #       id=2,
  #       author=
  #        #<struct User
  #         id=1,
  #         first_name="Stephen",
  #         last_name="Best",
  #         email="bestie@gmail.com",
  #         posts=#<SequelMapper::AssociationProxy:0x007ffbc3c7cb50 @assoc_enum=#<Enumerator::Lazy: ...>, @removed_nodes=[]>>,
  #       subject="Object mapping part 2",
  #       body="Lazy load all the things!",
  #       comments=#<SequelMapper::AssociationProxy:0x007ffbc5935990 @assoc_enum=#<Enumerator::Lazy: ...>, @removed_nodes=[]>,
  #       categories=#<SequelMapper::AssociationProxy:0x007ffbc592fe50 @assoc_enum=#<Enumerator::Lazy: ...>, @removed_nodes=[]>>]

  # And then access the comments and so on ...
```
