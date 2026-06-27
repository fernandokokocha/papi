# Per-Response Schemas (OpenAPI-shaped responses)

**Date:** 2026-06-27
**Status:** Approved design, pending implementation plan

## Problem

Today an `Endpoint` carries exactly two body schemas: `output` (rendered for any
2xx status) and `output_error` (rendered for everything else), plus an operation
`note`. A separate `responses` table lists the status codes an endpoint can
return, but each row holds only `code` + `note` — no schema of its own.

This forces every endpoint into a single success shape and a single error shape.
Real APIs return a different body per status code (e.g. `200`, `201`, `404`,
`422`). We want each response code to own its own body schema, which is exactly
how OpenAPI models `responses: { "200": {...}, "404": {...} }`.

## Goal and scope

- **In scope:** reshape the internal data model so each response code owns its
  schema + note, and update every consumer (models, diff, services, React form,
  ERB views, test server, seeds, RSpec).
- **Out of scope (this work):** building an OpenAPI exporter or importer. The
  model must *map cleanly* to OpenAPI; producing/consuming OpenAPI documents is a
  later effort.
- **No system/E2E tests** in this work.
- **No data migration.** The dev database is rebuilt via `bin/rails dev:setup`
  (migrations edited in place + seeds), so existing rows are discarded rather
  than migrated.

## Decisions (from brainstorming)

1. OpenAPI goal = **data model only**.
2. Response UI = **unified per-code blocks** — one section per response code,
   each showing `code + note + its own schema editor`. Replaces the old
   "Responses" list and both "Output" / "Output for Errors" sections.
3. Diff strategy = **minimal reuse** — delegate to existing diff engines rather
   than build a parallel one (see Diff section).
4. Empty bodies (204, DELETE, etc.) are represented by the existing `"nothing"`
   primitive schema, so a response always has a schema value (possibly empty).
5. Endpoint `note` stays as the operation-level description; each response keeps
   its own `note` (the response description).
6. **An endpoint must have ≥ 1 response** — enforced as soft validation in the
   React form (disable Save + inline warning), consistent with existing
   collision checks.
7. Response **codes are immutable** — users add/remove responses, never edit a
   code in place. This keeps code-keyed form params and React `key={code}` safe.

## Data model

Migrations are edited in place; `dev:setup` rebuilds the DB.

- `responses`: add `output` (string, not null). Keep `code`, `note`,
  `endpoint_id`, and the unique index on `[endpoint_id, code]`.
- `endpoints`: drop `output` and `output_error`. Keep `note`.

## Backend

### `Response` model
- Add `parsed_output`:
  `JSONSchemaParser.new(endpoint.version.entities).parse_value(output)`
  (same body as today's `Endpoint#parsed_output`).
- Remove the empty `serialize` stub.

### `Endpoint` model
- Delete `parsed_output` and `parsed_output_error`.
- `differs_from?` becomes: note diff via `DiffText::FromNotes`, plus
  `DiffResponses::FromResponses(previous.responses, responses).any_changes?`.
  The per-code schema comparison is folded into the diff orchestrator so there is
  a single entry point (no separate `Diff::FromValues` calls in the model).

### Diff: gut `DiffResponses::FromResponses`, delete `DiffResponses::Line`

Rationale: with `response = code + note + schema`, the old class reimplemented two
things that already exist — note comparison (`DiffText::FromNotes`) and
added/removed-whole-block handling (`Diff::FromValues` already covers this via its
`*ToNothing` / `NothingTo*` classes). Its only irreplaceable job is **matching
responses by code and keeping the two columns aligned**. Keep that, delegate the
rest.

New shape — one ordered list (sorted union of codes), each entry holds both sides:

```
DiffResponses::FromResponses#lines -> [ ResponseDiff, ... ]   # sorted by code

DiffResponses::ResponseDiff:
  code          # "200", "404", ...
  state         # :added | :removed | :changed | :no_change
  note_diff     # DiffText::FromNotes(before_note, after_note)
  output_diff   # Diff::FromValues(before_output_or_nothing, after_output_or_nothing)
```

- One-sided codes use the parser's `nothing` value on the absent side, so added =
  `Diff::FromValues(nothing, schema)` (after all-green), removed =
  `Diff::FromValues(schema, nothing)` (before all-red).
- `state`: `:added` / `:removed` for one-sided codes; for codes on both sides,
  `:changed` if `note_diff.any_changes?` or `output_diff.any_changes?`, else
  `:no_change`.
- `any_changes?` = `lines.any? { |l| l.state != :no_change }`.
- Both diff columns iterate the **same** `lines` list — left renders each entry's
  `note_diff.before` / `output_diff.before`, right renders `.after`. Alignment is
  automatic; no blank-padding bookkeeping.
- `DiffResponses::Line` is deleted; the `specs/responses` partial is removed.

Robustness payoff: all correctness-critical schema diffing flows through the
single, well-tested `Diff::FromValues`, including added/removed cases.

### Services — `Candidate::Create` / `Candidate::Update`
- `format_responses` maps each code to `{ code:, note:, output: }` (was
  `{ code:, note: }`), reading the nested per-code params (below).
- Endpoint attrs no longer include `output` / `output_error`.

### `Version#existing_endpoints_for_frontend`
- Drop `output` / `output_error` from the endpoint hash.
- Each response hash becomes `{ code:, note:, output: r.output }` (serialized
  schema string, as `output` already is).

### `TestServerController#output`
- Look up the `Response` by `?response=CODE`; render its `parsed_output`.
- No `response` param → default to the lowest-numbered 2xx response; if none,
  the lowest response code.
- Unknown code → `InvalidResponseCode` (unchanged behavior).

## Form params shape

Responses are posted keyed by their unique code (a hash, not a positional
array), which avoids index collisions:

```
version[endpoints_attributes][][responses][200][note]   = "..."
version[endpoints_attributes][][responses][200][output] = "<serialized schema>"
version[endpoints_attributes][][responses][404][note]   = "..."
version[endpoints_attributes][][responses][404][output] = "<serialized schema>"
```

`JSONSchemaForm` already emits the schema as a single serialized string in one
hidden input, so `[output]` is a scalar param. `format_responses` reads
`value[:note]` and `value[:output]` per code.

## React

### Shared response-block components
The per-code block currently lives inline (and duplicated) in `EndpointAdded`,
`EndpointDiff`, and `EndpointRemoved`. Extract:
- **`ResponseList` (editable):** per code → code label + note input +
  `JSONSchemaForm` (seeded `nothing` for new responses), keyed by `r.code`, with
  the param names above and `id={`${endpoint.id}-${code}`}`.
- **`StaticResponseList` (read-only):** per code → code + note +
  `StaticJSONSchema root={r.output}`.

Delete the "Output" and "Output for Errors" sections from all three components.

### Handlers (`EndpointAdded` / `EndpointDiff`)
- `addResponse` → push
  `{ code, note: "", output: { nodeType: "primitive", value: "nothing" } }`.
- new `updateResponseOutput(code, root)` → immutable-slice, mirrors
  `updateResponseNote`.
- `updateResponseNote`, `removeResponse` unchanged.

### `Form.jsx`
- `findCustomNameInEndpoints` → scan each response:
  `e.responses.forEach(r => found ||= findCustomName(r.output, name))`; drop
  `e.output` / `e.output_error`. This drives entity-reference highlighting and
  removed-entity bring-back.
- **Submit serialize** → per response `{ code, note, output: serialize(r.output) }`;
  drop endpoint-level outputs. Include serialized response outputs in the
  `anyChanges` comparison string (else the Save button mis-enables).
- **Load `useEffect`** → for each endpoint build two *independent* deserialized
  deep copies: editable `responses` and `original_responses`. They must not share
  node references, or editing the right column would mutate the read-only left
  column. Drop `output` / `output_error` and their `original_*`.
- `addEndpoint` default → `responses: []` (no top-level outputs).
- `restoreEndpoint` ("bring back") → deep-clone `original_responses` back into
  `responses` (not a reference assign); drop output/output_error restore lines.
- **≥1 response validation** → in `validate`, mark a non-removed endpoint invalid
  when `responses.length === 0`; fold into the Save-disable condition and show an
  inline warning on the endpoint block.

### Mutation-isolation note
The two genuine edge-case hotspots are (1) load-time deep copy of editable vs
original response schemas and (2) the restore path. Both must deep-clone; today's
`original_responses = responses` reference assignment is not safe once responses
carry mutable schema nodes.

## ERB views

`_endpoint_diff`, `_endpoint_new`, `_endpoint_removed`:
- Remove the "Output" and "Output for Errors" sections.
- Replace the `specs/responses` render with a per-code block loop over
  `DiffResponses::FromResponses#lines`. Per `ResponseDiff`: render the block with
  a state color and the schema diff via the existing `specs/json` partial
  (left = `output_diff.before`, right = `output_diff.after`); note via
  `specs/text`.
- Color mapping (consistent with the existing endpoint-level amber pattern):
  - `:added` → green block
  - `:removed` → red block
  - `:changed` → amber header + border; inner schema diff still shows
    fine-grained green/red lines
  - `:no_change` → neutral
- Expand/collapse condition becomes
  `endpoint.responses.any? { |r| r.parsed_output.expandable? }`.
- Delete the now-unused `specs/responses` partial.

## Seeds

Update `db/seeds*` to create responses with schemas (replacing endpoint
`output` / `output_error`).

## Tests (RSpec + FactoryBot)

- `Response` factory gains `output`; update endpoint factory + seeds.
- Model specs:
  - `Response#parsed_output`.
  - `Endpoint#differs_from?` across: response added, removed, note-only change,
    schema-only change, and no change.
- `DiffResponses::FromResponses` spec: union + sort ordering, `state` derivation
  for all four cases, nothing-substitution on one-sided codes, `any_changes?`.
- `Candidate::Create` / `Candidate::Update`: `format_responses` maps
  `{ code, note, output }`; schema round-trips through save.
- `TestServerController`: by-code selection, default fallback (lowest 2xx, then
  lowest code), unknown code raises.

## Risks

- **React mutation bugs** in load + restore (deep-clone discipline) — the main
  risk; covered by careful copies and exercised through the existing form flows.
- **Change-detection drift** if response outputs are omitted from the `anyChanges`
  comparison — easy to forget, cheap to get right.
- Everything else is mechanical: the schema editor component is reused unchanged;
  the change is structural (2 fixed editors → 1 editor per response) plus one new
  field on the response object.
