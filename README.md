# Papi - API spec done right

## Supported Ruby/Node versions

* Ruby 3.4.1
* Node v23.11 (npm 10.9.2)

## Reset DB and load fixtures

```
rake db:migrate:reset
bin/rails db:fixtures:load
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
