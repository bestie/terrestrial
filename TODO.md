# TODOs

In no particular order

## General
* Refactor, methods too big, objects missing
* Name things better

## Querying
* Querying API, what would a repository with some arbitrary queries look like?
  - e.g. an association on post called `burger_comments` that finds comments
    with the word burger in them
* Add other querying methods from assocaition proxies or remove entirely
  - Depends on nailing down the querying API
* When possible optimise blocks given to `AssociationProxy#select` with
  Sequel's `#where` with block [querying API](http://sequel.jeremyevans.net/rdoc/files/doc/cheat_sheet_rdoc.html#label-AND%2FOR%2FNOT)

## Associations
* Read only associations
  - Loaded objects would be immutable
  - Collection proxy would have no #push or #remove
  - Skipped when dumping
* Associations defined with a join
* Composable associations

# Hopefully done

## Persistence
* Efficient saving
  - Part one, if it wasn't loaded it wasn't modified, check identity map
  - Part two, dirty tracking

## Associations
* Eager loading

## Configuration
* Automatic config generation based on schema, foreign keys etc
* Config to take either a classes or callable factory
