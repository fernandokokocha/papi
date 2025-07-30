# Papi - API spec done right

## Supported Ruby/Node versions

* Ruby 3.4.1
* Node v23.11 (npm 10.9.2)

## Reset DB

For convenience, early in the development, migrations can be updated in place. After it's done, all the database should be wiped and recreated via migrations like this:

```
rake db:migrate:reset
```

Occasionally, this requires setting up the test database:

```
bin/rails db:test:prepare
```

In order to have some data after the wipe, fixtures are present and used in the development.

## Load fixtures

Because of circular dependency (`Version` belongs to `Candidate` but `Candidate` can belong to `Version` via `:base_version`) one needs to patch the fixtures every time they are loaded

```
bin/rails db:fixtures:load
bin/rails dev:fill_fixtures_dependencies
```

To quickly reset and populate dev database, use custom rake task (`lib/tasks/dev_setup.rake`):

```
bin/rails dev:setup
```

## Tests

`bundle exec rspec`

## Rubocop

`bin/rubocop`

## Deployment

### Prerequisites

* lastpass CLI v1.6.1
* Account for a given user + appropriate secrets stored there (see `.kamal/secrets`)

### Deployment command

`kamal deploy`
