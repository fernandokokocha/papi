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

- `bin/dev` — dev server. Not `bin/rails server`: it also runs the Tailwind and
  Vite watchers, without which class changes silently no-op.
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
raises, and the editor offers "nothing" only at an endpoint input or a response
output root.

**A one-of has at least two branches, and no two branches share a named type.**
`(string|string)` and a bare `(string)` are both meaningless, and a branch may
not itself be a one-of. "Named type" means a primitive or an entity reference,
so `({a:string}|{b:number})` is fine — two object branches have no name to
collide. Beware: **all of this is enforced by the React editor alone**
(`OneOfNode.jsx` withholds taken types from the other branches' `TypeSelect` and
blocks the delete button at two branches). The parser accepts every one of these
shapes, and no model validates them. Fix a violation at the editor, or add the
validation deliberately — don't assume a parsed tree obeys the rule.

**The parser is hand-written and deliberately loose.** It has no tokenizer and
no grammar library, and these are simplifications, not oversights — per
"simplicity over correctness", a malformed spec may raise a bare `RuntimeError`
rather than be diagnosed:

- primitives are matched with `start_with?`, so `stringify` parses as `string`;
- `split_by_comma` tracks only `{}` depth, which suffices because a comma can
  never appear inside `[]` or `()` without braces around it;
- an attribute's name is everything before its first `:`.

**There are two implementations and they must agree.** Ruby parses for diffing,
validation and the mock server; the React editor parses on every keystroke via
`app/javascript/helpers/{deserialize,serialize}.js`. A grammar change means
touching both sides and both sets of specs. The JS side calls an entity
reference `custom` because it cannot resolve names client-side, and it matches
primitives exactly where Ruby matches by prefix.

**Entities nest to any depth; only cycles are banned.** `Order` may reference
`Customer`, which references `Address`, and so on — there is no depth limit.
Cycles are rejected by `Version#entity_references_are_acyclic` (via
`EntityReferences`), and not out of paranoia: a circle *hangs*
`Diff::EntityToEntity` and `to_example_json` rather than raising, and a hang is
the one failure mode simplicity-over-correctness does not cover. The editor
won't offer a cycle-forming name at any depth (`helpers/entityReferences.js`),
so the validation is a backstop.

**Expansion, unlike nesting, stops after one level.** These are different
questions — arbitrary depth is *stored*, one level is *rendered*.
`Node::Entity#expand` returns `parsed_root` without expanding it, so a nested
reference shows as a leaf name. That is load-bearing, not an oversight:
`ExpandedLineIndex#rows_for` counts a reference as its root's line count, and
expanding deeper would shift every comment anchor below it.

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

**Two independent JS pipelines.** Stimulus controllers
(`app/javascript/controllers/`) load through importmap; the React schema editor
(`app/javascript/components/`, `entrypoints/`) builds with Vite. A local module
imported by a Stimulus controller must be pinned in `config/importmap.rb` or it
resolves to nothing and the controller dies silently — a green `bin/vite build`
proves nothing about it.

**Turbo Drive stays off** (`Turbo.session.drive = false`). The sidebar scroll-spy
highlight relies on native anchor navigation and full page loads. Forms that
need Turbo Streams opt in per element with `data: { turbo: true }`. Always bind
`form_with` to an explicit model: an unbound `form_with scope: :x` picks up `@x`
from the rendering controller and prefills itself.

**Design.** `/design-preview` (`app/views/design_preview/show.html.erb`) is the
palette, rendered. Read it rather than a written spec, and extend it when a new
element type appears. Shared styles live in `app/assets/tailwind/application.css`
— there is no `app/assets/stylesheets/`. Tailwind classes must be complete
literal strings; never interpolate a class name.
