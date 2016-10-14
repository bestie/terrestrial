# TODOs

In no particular order

* User defined default settings for all mappings
* Refactor, methods too big, objects missing
* Name things better
* Full adaptorization of the database, refactor some Sequel specific things
  into the adapter

## Candidate features to consider
* Column aliasing
* Callbacks e.g. after_save, after_insert as functions defined in mapping
* Database generated IDs and Timestamps (perhaps implemented as callbacks)
* When possible optimise blocks given to `AssociationProxy#select` with
  Sequel's `#where` with block [querying API](http://sequel.jeremyevans.net/rdoc/files/doc/cheat_sheet_rdoc.html#label-AND%2FOR%2FNOT)
* `#eager_load!` that raises an error when traversing outside the eagerly
  loaded data

# Hopefully done

## Persistence
* Efficient saving
  - Part one, if it wasn't loaded it wasn't modified, check identity map
  - Part two, dirty tracking
* Support swapping out DB for in memory datasets

## Associations
* Eager loading

## Querying
* Querying API, what would a repository with some arbitrary queries look like?
  - e.g. an association on post called `burger_comments` that finds comments
    with the word burger in them

## Configuration
* Automatic config generation based on schema, foreign keys etc
* Config to take either a classes or callable factory

# Not happening (at least for now)

## Associations
* Read only associations
  - Loaded objects would be immutable
  - Collection proxy would have no #push or #remove
  - Skipped when dumping
* Associations defined with a join
* Composable associations
