# Candidate Commenting — Design

**Date:** 2026-07-02
**Status:** Approved for planning

## Goal

Let group members leave comments on candidates, GitHub-style. Comments support one
level of replies, can be pinned to a specific endpoint / entity / response / part /
line, persist through merge and reject (so they double as an archeology tool), and
can be marked resolved (hidden by default, revealable).

## Key domain constraints discovered

- **Endpoint / entity / response row ids are not stable.** `Candidate::Update#call`
  runs `endpoints.destroy_all` + `entities.destroy_all` and recreates everything from
  the form on *every* candidate edit. A comment therefore cannot anchor to a row id —
  it must anchor to **logical identity** that survives edits and merge:
  - Endpoint → `(http_verb, path)`
  - Response → endpoint + `code`
  - Entity → `name`
  - Part → which text block (`note` / `output` / `root`)
  - Line → a line index within that block's raw stored text
- **Candidates persist.** Candidates are never deleted; they move to `merged` /
  `rejected` states and their versions are kept. So comment persistence is free as long
  as comments hang off the candidate.
- **The candidate page renders a diff.** Base version vs current version, side by side,
  with response outputs shown as JSON-schema trees (not raw text). "A line of a
  response" is anchored to a **line index in the raw stored text** (`response.output`,
  `response.note`, `endpoint.note`, `entity.root`), never to the rendered diff DOM.
- **Candidate gets attribution; admin irrelevant.** Candidates currently have no
  author/owner field. This design adds:
  - **`candidates.author_id`** — the creating user, set in `Candidate::Create`
    ("Proposed by …", dated by the existing `created_at`).
  - **`candidates.decided_by_id` + `candidates.decided_at`** — the user (and time) who
    took the candidate out of `open`, set in **both** `Candidate::Merge` and
    `Candidate::Reject`. One shared pair; the verb comes from `aasm_state`
    (`merged` → "Merged by …", `rejected` → "Rejected by …"). Named `decided_*` to avoid
    collision with the comment-thread "resolve".

  All three render on the candidate and version pages; the author is also used to
  highlight that author's comments (the GitHub "Author" badge). The `User#role` admin enum
  exists but is treated as irrelevant for this feature. Authorization keys off group
  membership only.

## Scope decisions

- **Threading:** one level deep (GitHub-style). A root comment has flat replies; replies
  cannot be replied to.
- **Pinning depth:** full — candidate / endpoint / entity / response / part / line.
- **Comments are immutable** in v1: no edit, no delete. This sidesteps the edge cases
  (deleting a root that has replies, editing a comment after it has replies) and fits the
  archeology-tool intent. Can be added later.
- **Resolve:** a **root** thread can be resolved/reopened; replies are not individually
  resolved. Resolved threads are hidden by default with a "Show resolved" toggle.
  Resolvability is orthogonal to anchoring and applies uniformly to every comment type,
  so it is built **last, as its own stage**, on top of all the create/render stages.
- **Body:** free text (plain text) — no markdown, mentions, or formatting. Unicode is
  fully supported, so **emoji work for free** (typed/pasted); there is no emoji picker or
  reactions UI in v1.
- **Candidate authorship:** the candidate's author (new `author_id`) is rendered on the
  candidate/version pages, and that author's comments are highlighted in threads.

## Authorization (`CommentPolicy`)

Mirrors `CandidatePolicy#show?` (same group as the candidate's project's group):

- **Create / reply:** any member of the candidate's group.
- **Resolve / reopen:** any member of the candidate's group (GitHub "anyone with write
  access can resolve a conversation"). *Revisit when building the resolve stage:* now that
  candidates have an author, we could instead scope resolve to the root comment's author
  or the candidate's author. Default remains any-group-member unless changed then.
- **Edit / delete:** not supported in v1.

## Data model

### `candidates` new columns

All nullable (existing fixture/seed candidates have no attribution):

- `author_id` → `users` — set by `Candidate::Create` to the current user.
- `decided_by_id` → `users` — set by `Candidate::Merge` and `Candidate::Reject` to the
  current user.
- `decided_at` datetime — set alongside `decided_by_id`.

Rendered on the candidate and version pages ("Proposed by … · Merged/Rejected by …");
`author` is also used to highlight that author's comments.

### `comments` table

`resolved_at` / `resolved_by_id` are added in the **resolve stage**, not the initial
`comments` migration (per DB-reset-in-place workflow, they can be folded into the create
migration or added later — either way they stay unused until the resolve stage).

```
comments
  candidate_id        bigint, not null, indexed   # comments live on the candidate → survive merge/reject
  author_id           bigint, not null            # → users (the comment's author)
  parent_id           bigint, nullable, indexed   # a reply; root when null. one-level enforced by validation
  body                text,   not null
  resolved_at         datetime, nullable          # resolve stage
  resolved_by_id      bigint, nullable            # resolve stage; → users
  -- anchor (only meaningful on roots; replies inherit the parent's anchor) --
  scope               string, not null            # candidate | endpoint | entity | response
  endpoint_path       string, nullable            # endpoint & response scopes
  endpoint_http_verb  integer, nullable           # endpoint & response scopes (matches Endpoint enum)
  entity_name         string, nullable            # entity scope
  response_code       string, nullable            # response scope
  part                string, not null            # whole | note | output | root
  line                integer, nullable           # line index within the part's raw text
  anchor_snapshot     text, nullable              # exact text of the anchored line/block at pin time
  created_at, updated_at
```

Anchor columns hold **logical identity**, never row ids, so anchors survive the
`destroy_all`-and-recreate churn and survive merge (the version's endpoints keep the same
verb/path/code/name).

Indexes for v1: `candidate_id`, `parent_id`. The anchor columns are **not** indexed — see
querying below.

### Anchor `scope` × `part` matrix

| scope | valid `part` | other anchor cols set |
| --- | --- | --- |
| `candidate` | `whole` | none |
| `endpoint` | `whole`, `note` | `endpoint_path`, `endpoint_http_verb` |
| `entity` | `whole`, `root` | `entity_name` |
| `response` | `whole`, `note`, `output` | `endpoint_path`, `endpoint_http_verb`, `response_code` |

`line` may be set only when `part` addresses a text block (`note` / `output` / `root`).

## Querying & performance

No performance concern at this scale (a candidate has a handful of endpoints and, ever, a
few dozen comments).

- **All comments for a candidate:** `WHERE candidate_id = ?` on the `candidate_id` index.
- **Per-anchor lookups never hit SQL.** The candidate page needs every comment anyway, so
  load them all in one query and group in memory:

  ```ruby
  comments  = @candidate.comments.includes(:author, replies: :author)   # + :resolved_by from resolve stage
  roots     = comments.select(&:root?)
  by_anchor = roots.group_by(&:anchor_key)   # anchor_key = [scope, path, verb, name, code, part, line]
  ```

  Each endpoint / entity / response / line partial looks up its threads from `by_anchor`.
  No N+1, no per-anchor SQL.

## Components

Each unit has one clear purpose and is independently testable.

### Candidate attribution
- `candidates.author_id`, `decided_by_id`, `decided_at` migration; `Candidate belongs_to
  :author` and `belongs_to :decided_by` (both `class_name: "User", optional: true`).
- `Candidate::Create` assigns `author` = current user.
- `Candidate::Merge` and `Candidate::Reject` assign `decided_by` = current user and
  `decided_at` = now.
- Rendered on `candidates/show` and `versions/show` ("Proposed by … · Merged/Rejected
  by …"); the merge/reject verb is derived from `aasm_state`.
- `Comment#by_candidate_author?` (added in Stage 2) — the comment's author is the
  candidate's author; drives the highlight/badge in thread rendering.

### `Comment` (model)
- `belongs_to :candidate`, `belongs_to :author` (User), `belongs_to :parent` (Comment,
  optional), `has_many :replies`.
- Validations: reply's `parent` must itself be a root (enforces one level); anchor
  validity per the scope × part matrix; `body` present.
- `root?`, `reply?`, `by_candidate_author?`.
- `anchor` → returns a `CommentAnchor` built from the row's anchor columns.
- `anchor_key` — the in-memory grouping key.
- Resolve stage adds: `belongs_to :resolved_by` (User, optional), `resolved?`,
  `resolve!(by:)` / `reopen!`.

### `CommentAnchor` (value object)
Holds the logical target (`scope`, path/verb/name/code, `part`, `line`, `snapshot`).
Depends on nothing but a `Version`.
- `.from_params(params)` — build from form input.
- `#resolve_against(version)` → `{ target:, current_text:, outdated:, label: }`.
  - Finds the current endpoint/entity/response by logical identity.
  - `current_text` is the addressed block's text (or the specific line).
  - `outdated:` true when the target is gone, or the current line/block text ≠
    `anchor_snapshot`.
  - `label` reads like `GET /users → 200 → output · line 14`.
- `#to_columns` — the hash of anchor columns to persist.

All logical-identity logic lives here, out of the model and views.

### `CommentsController`
Nested under candidate. `create` (root + reply) with Turbo Stream responses (append
thread / reply), authorized via `CommentPolicy`. `resolve` / `reopen` actions are added in
the resolve stage. No `update` / `destroy` in v1.

### `CommentPolicy`
As in Authorization above.

### Views + Stimulus
- **Conversation section** at the bottom of the candidate page: candidate-level (`scope:
  candidate`) threads, a new-comment form, and per-thread reply forms. Comments by the
  candidate's author are highlighted with an "Author" badge.
- **Inline threads** attached to endpoint / entity cards, response rows, and lines, read
  from the in-memory `by_anchor` map.
- **Anchor hooks:** `data-` attributes on the existing endpoint / entity / response / line
  partials so a Stimulus controller knows which logical anchor a "＋ comment" affordance
  targets.
- **Line-selection controller:** click/select a line in the diff, highlight it, capture
  `(target, part, line, snapshot)` into the comment form.
- **Resolve (resolve stage):** per-thread resolve/reopen control and a "Show resolved"
  toggle (resolved hidden by default), applied uniformly across candidate-level, anchored,
  and line-anchored threads.
- Stimulus controllers: comment form, reply, line-selection, and (resolve stage) resolve
  toggle + show-resolved toggle. Turbo Streams for live append.

### Fixtures
`test/fixtures/comments.yml` (loaded by `bin/rails dev:setup` via `db:fixtures:load`), so
each render-only stage is examinable in the running dev app with seeded threads.

## Outdated detection (line/part drift)

At pin time we store `anchor_snapshot` — the exact text of the anchored line (or block).
On render, `CommentAnchor#resolve_against(current_version)` compares the current text to
the snapshot. If the target is gone or the text differs, the thread renders as
**Outdated**, still showing its original snapshot for archeology. No diff-tracking — a
fingerprint compare. Good enough for v1.

## Testing

- **Candidate attribution:** `Candidate::Create` sets `author`; `Candidate::Merge` /
  `Candidate::Reject` set `decided_by` + `decided_at`; pages render "Proposed by …" and
  "Merged/Rejected by …".
- **Model specs:** one-level threading validation, anchor validity (scope × part matrix),
  `root?`/`reply?`, `anchor_key`. Resolve stage adds `resolve!`/`reopen!`, `resolved?`.
- **`CommentAnchor` specs:** `from_params`, `resolve_against` (found / gone / drifted →
  outdated), `label`, `to_columns`.
- **Request specs:** policy enforcement (group membership), `create` (root + reply).
  Resolve stage adds `resolve`/`reopen`.
- **FactoryBot:** a `comment` factory with traits for each scope (and, from the resolve
  stage, a resolved trait).

## Staging

Each stage is an independently mergeable, testable increment, from the easiest anchor to
the hardest.

| # | Stage | Type | Proves |
| --- | --- | --- | --- |
| 1 | Candidate attribution: `author_id` + `decided_by_id`/`decided_at`, captured in Create/Merge/Reject, rendered as "Proposed by … · Merged/Rejected by …" | write | candidate attribution (prerequisite for the Author badge) |
| 2 | `Comment` model + migration + `comments.yml` + candidate-level Conversation rendered, with Author badge | render-only | thread / reply visual design + author highlight |
| 3 | Candidate-level interactive: create + reply | write | full controller / policy / Turbo / Stimulus plumbing on the easy anchor |
| 4 | Inline threads on endpoint / entity / response / part via `CommentAnchor` | render-only | where pinned threads sit on the cards |
| 5 | "＋ comment" affordances on those targets → create pinned threads | write | pinned-thread write path (reuses stage 3 plumbing + anchor) |
| 6 | Line-anchored threads + Outdated marker | render-only | hardest layout + drift/snapshot concept |
| 7 | Line-selection prototype: pick a line in the diff, highlight it, capture the anchor; creates no comment | interaction | the novel line-picking UX in isolation |
| 8 | Wire the selector to comment creation | write | full line-pin write path |
| 9 | Resolvability: resolve/reopen + resolved rendering + "Show resolved" toggle, across all comment types | write | orthogonal resolve feature over everything above |

Stages 6 and 7 are independent (both need only the existing diff rendering) and may be
swapped. Resolve is deliberately last (stage 9) since it applies uniformly to every
comment type built in stages 2–8.

## Explicit non-goals (v1)

- Editing or deleting comments.
- Infinitely nested replies.
- Markdown, @mentions, attachments, reactions, or an emoji picker (typed/pasted emoji do
  work, since the body is Unicode text).
- Notifications / email.
- Real-time updates beyond the standard Turbo Stream on submit.
- Surfacing candidate comments on the merged version's own page (comments live on the
  candidate page).

## Design palette

Follow the White & Sky palette in `CLAUDE.md`. Resolved threads use the muted/secondary
treatment; Outdated uses an amber accent consistent with the existing "changed" tint.
