# Papi - API spec done right

## Supported Ruby version

* Ruby 3.4.1

## Start the dev server

Use `bin/dev` — **not** `bin/rails server`. `bin/dev` runs Rails and the Tailwind watcher together (see `Procfile.dev`). Without it, Tailwind won't recompile when you change views and newly-used utility classes will silently render as no-ops.

```
bin/dev
```

## Reset the dev database

```
bin/rails dev:setup
```

Wipes and recreates the database through the migrations, loads the fixtures, and
imports the Petstore document. It prints the logins when it finishes. Early in the
development, migrations are edited in place rather than added to, so this is how a
changed migration is picked up.

Occasionally, this requires setting up the test database:

```
bin/rails db:test:prepare
```

## Mail in development

By default, mail is written to `tmp/mails` as `.eml` files rather than sent.

With `bin/dev` running, every mailer can also be rendered in the browser at
<http://localhost:3000/rails/mailers> without sending anything. The previews live in
`spec/mailers/previews` and render against the dev database.

To send through the real SMTP server instead — the only way to check the credentials
or where a message lands — set `MAIL_DELIVERY`:

```
MAIL_DELIVERY=smtp bin/dev
```

Opt-in on purpose: the default cannot email a real person by accident, and cannot
spend the sending quota that the domain's personal mail shares.

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
