# CLAUDE.md

@~/.claude/bartech-way.md

The Bartech Way covers how to write code here (refactoring, comments, defensive
programming). This file covers only what is specific to Papi and cannot be read
off the code cheaply. Nothing is repeated between the two.

## What Papi is

"Swagger but better" — the same job as OpenAPI, with far less of its surface and
a few things it doesn't have at all.

What it adds:

- **Review workflow.** A spec change is a pull request, not a commit.
- **Semantic diff** between versions, rendered side by side, that understands
  the schema rather than the text — a reordered object is `no_change`.
- **Inline comments** anchored to a part or a single line of a schema, which
  survive the next version.
- **A mock server** — the declared responses answer real HTTP requests, so a
  spec is runnable the moment it is written.
- **A one-line schema language** — `{id:number,customer:Customer}` where OpenAPI
  needs a dozen lines of nested YAML.

A `Project` holds a chain of published `Version`s and a stream of `Candidate`s —
the pull requests, `open → merged | rejected` (AASM). Merging a candidate
promotes its latest version.

A version owns `Endpoint`s (verb + path + path/query params + input schema +
`Response`s) and `Entity`s (named reusable schemas). Cutting a new version
`amoeba_dup`s all of them, so **records are copied per version and their ids are
not stable across versions** — anything that must survive a new version keys on
logical identity instead (see Comment anchoring).

Two things are rendered from a spec: a side-by-side diff against the previous
version, and a mock server (`TestServerController`) that answers real HTTP
requests under `/projects/:p/versions/:v/*` with example JSON built from the
declared response schema.

## Working here

**Design in conversation, then write the code.** No spec document, no plan file,
no design doc unless one is asked for — the discussion settles the design, and
the code is the next artifact after it. Anything worth keeping from that
discussion is a decision record, not a plan.

## Commands

- `bin/dev` — dev server. Not `bin/rails server`: it also runs the Tailwind
  watcher, without which class changes silently no-op.
- `bin/rails dev:setup` — wipe + recreate + load fixtures. Migrations are edited
  in place at this stage rather than added to.
- `bundle exec rspec` — the suite. `test/` holds only legacy fixtures.
- `bin/rubocop`, `bundle exec brakeman`.

## The schema DSL

The core of the app.

**A whole schema is one string in one column** — `endpoints.input`,
`responses.output`, `entities.root`. There are no schema tables and no JSON
columns; the database knows nothing about the structure. Every read parses the
string into a `Node::*` tree (`JSONSchemaParser`), every write serializes a tree
back (`Node#serialize`), and the round trip is exact. Nothing may cache a parsed
tree across a write.

```
string | number | boolean | null        primitives
{name:T,other?:T}                       object; `?` marks optional
[T]                                     array
(A|B)                                   one-of
Customer                                reference to an Entity by name
                                        empty string → Node::Nothing
```

**`Nothing` is not `null`.** `Node::Nothing` is *absence* — nothing was
declared, and it serializes to the empty string. `Node::Primitive(kind: "null")`
is JSON's `null`, a first-class type that can sit in a union like
`(string|null)`. Nothing is legal only as a whole value: `parse_value("")`
raises, and the form offers "nothing" only at an endpoint input or a response
output root (`SchemaForm::Blocks#locals_for`).

**A one-of has at least two branches, and no two branches share a named type.**
`(string|string)` and a bare `(string)` are both meaningless, and a branch may
not itself be a one-of. "Named type" means a primitive or an entity reference,
so `({a:string}|{b:number})` is fine — two object branches have no name to
collide. Beware: **all of this is enforced by the form alone**
(`SchemaForm::Rows` hands each branch the `taken` names so the type select can
withhold them, and marks a branch `removable` only above two). The parser
accepts every one of these shapes, and no model validates them. Fix a violation
at the form, or add the validation deliberately — don't assume a parsed tree
obeys the rule.

**The parser is hand-written and deliberately loose.** It has no tokenizer and
no grammar library, and these are simplifications, not oversights — per
"simplicity over correctness", a malformed spec may raise a bare `RuntimeError`
rather than be diagnosed:

- `split_by_comma` tracks only `{}` depth, which suffices because a comma can
  never appear inside `[]` or `()` without braces around it;
- an attribute's name is everything before its first `:`.

**There is one implementation, and it is Ruby's.** The parser serves diffing,
validation, the mock server and the form alike — the form renders every schema
server-side and re-parses on each edit, so a grammar change is one change and
one set of specs. It matches a primitive by exact name; it used to match by
prefix, which read an entity named `numberOfItems` back as `number`.

**An entity name starts with an uppercase letter.** `SchemaForm::Blocks` refuses
the name otherwise and `OpenAPI::Import` capitalizes every component name, but
no model validates it — a lowercase name parses fine, so this is convention,
not correctness.

**Entities nest to any depth; only cycles are banned.** `Order` may reference
`Customer`, which references `Address`, and so on — there is no depth limit.
Cycles are rejected by `Version#entity_references_are_acyclic` (via
`EntityReferences`), and not out of paranoia: a circle *hangs*
`Diff::EntityToEntity` and `to_example_json` rather than raising, and a hang is
the one failure mode simplicity-over-correctness does not cover. The form
won't offer a cycle-forming name at any depth
(`Version#referenceable_entity_names`), so the validation is a backstop.

**Expansion goes all the way down.** `Node::Entity#expand` returns
`parsed_root.expand`, so a reference becomes its entity's body and every
reference inside that body is replaced too, down to primitives. Nothing bounds
the recursion but `Version#entity_references_are_acyclic` — a circle recurses
forever rather than raising, which is the other reason cycles are banned.

`ExpandedLineIndex#rows_for` has to agree with it. It counts a collapsed
reference as `Entity#to_lines`, which is expanded for exactly that reason, so
the index a comment anchors to survives expanding the block above it. Change one
and the other has to move with it.

## Diff

`Diff::FromValues` dispatches on the pair of node classes by constantizing
`Diff::<Before>To<After>` — six node types, so thirty-six classes in
`app/models/diff/`. Adding a node type means adding its full row and column.
Output is two `Diff::Lines` columns padded with blank lines so before and after
stay row-aligned for side-by-side rendering.

**Two different equalities live in two different layers. Keep them there.**

- *Semantic equivalence* ("do these schemas mean the same thing?") lives
  entirely in `Diff`. `Diff::ObjectToObject` matches attributes by name and
  re-lays-out the before column into the after's order, which is why a reordered
  object reads as `no_change`. Every app-level "did this change?" question —
  `differs_from?`, `any_changes?` — goes through here.
- *Structural identity* ("did the parser build the tree I wrote, in that
  order?") is `Node#==`, and its only caller is the parser spec. It stays
  positional: order is semantically meaningless but materially preserved,
  because it drives diff line order, `to_example_json` key order, and the
  serialize round trip.

Do not "fix" `Node#==` to be order-insensitive — that only weakens the parser
spec's one assertion.

## Comment anchoring

`CommentAnchor` addresses a comment by logical identity — endpoint path +
verb, entity name, response code, part, optional line — and never by
`endpoint_id`, because those ids die with each new version.

The path in an identity is the path *shape*: param names are ours, not the
client's, so `Endpoint.identity_path` erases them and `/user/:id` and
`/user/:user_id` are one endpoint. Everything that compares endpoints funnels
through it. `comments.endpoint_path` still stores the raw path — normalize when
comparing, never on write, or labels render as `GET /user/:`.

`dom_id` is an MD5 of the key because the key holds paths and symbols that are
invalid in HTML ids. Ruby is its only producer; JS only consumes ids Ruby
rendered, so the key formula can change freely. Its derived ids
(`<dom_id>_form`, `_line_threads`, `sidebar_count_<dom_id>`) are untyped string
glue shared between ERB and JS, and nothing checks that the suffixes match.

## Frontend

**All JavaScript is Stimulus, loaded through importmap.** There is no bundler
and no build step — no npm, no `package.json`. A local module imported by a
controller must be pinned in `config/importmap.rb` or it resolves to nothing and
the controller dies silently, with no error anywhere to say so.

**Turbo Drive is on**, so every form and link is intercepted unless it opts out.
Two consequences. A redirect after anything but `POST` must say
`status: :see_other`: `fetch` rewrites the method to `GET` only on a 302 from a
POST, so a 302 after `PATCH` or `DELETE` is replayed with the same method —
`candidates#update` would `PATCH` itself. And a response that is not a page
needs `data: { turbo: false }` on the link that reaches it; `OpenAPIController`
is the only one, and it `send_data`s a file.

Drive was off until 2026-08-25, to protect a `:target` rule that highlighted the
anchored card (`fa567a8`). That CSS died with the v1 stylesheet — the scroll-spy
highlight is `sidebar_controller.js` now, and owes Drive nothing.

Always bind `form_with` to an explicit model: an unbound `form_with scope: :x`
picks up `@x` from the rendering controller and prefills itself.

**Design.** `/design-preview` (`app/views/design_preview/show.html.erb`) is the
palette, rendered. Read it rather than a written spec, and extend it when a new
element type appears. Shared styles live in `app/assets/tailwind/application.css`
— there is no `app/assets/stylesheets/`. Tailwind classes must be complete
literal strings; never interpolate a class name.
