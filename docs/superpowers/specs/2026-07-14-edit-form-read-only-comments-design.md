# Read-only Comments in the Edit Candidate Form — Design

**Date:** 2026-07-14
**Status:** Approved for planning

## Goal

While editing an existing candidate, show the candidate's review comments **read-only**
inline next to the endpoint / entity they were pinned to, so the editor remembers where
to make the requested changes. A `new` candidate always starts with no comments, so this
targets the `edit` action only.

This extends the candidate commenting system (see
`2026-07-02-candidate-commenting-design.md`), which currently renders comments only on the
**show** page.

## Key constraint discovered

The **show** page renders comments server-side in ERB, woven into a *static* diff — anchored
to logical identity (endpoint `verb`+`path`, entity `name`) and, for line comments, to line
indices in the stored text.

The **edit** page is a separate **React** app (`app/javascript/components/Form.jsx`,
mounted on `#react-form`). Endpoint/entity text is live-editable React state, so line
indices drift as you type, and anything rendered *inside* a card must live in the React tree.

Reproducing the show page's line-by-line weaving inside the live editor is the expensive
(~10×) part. Rendering pre-built comment HTML at the card level is not.

## Approach

Render each card's comments to an **HTML string server-side** (reusing every existing
`comments/*` partial, in a new read-only mode), pass a small `{card-identity → html}` map
into React on `#react-form`, and have each endpoint/entity card inject its blob via
`dangerouslySetInnerHTML`. No comment markup is reimplemented in JSX; React only *places*
pre-rendered HTML.

React already knows each card's logical identity, so there is no MD5/`dom_id` duplication in
JS, and there are only **two** insertion points (endpoint card, entity card). This is ~3–4×
the effort of a single consolidated panel, well under the 10× line-weaving alternative.

### Card identity keying

- Endpoints keyed by **original** logical identity (`"#{http_verb}\x00#{path}"`), so
  comments stay pinned to a card even if its path/verb is renamed mid-edit. `new` endpoints
  (no original identity) get nothing; `removed` endpoints keep their comments (archeology).
- Entities keyed by `name` (original name).

`http_verb` is the string enum (e.g. `"verb_get"`) that both `existing_endpoints_for_frontend`
and the React endpoint objects already carry, so keys match without conversion.

## Line comments (the fidelity compromise)

Line-anchored comments are the most important to surface (they say *where* to change the
spec), but weaving them into live editor rows is the 10× part. Simplification:

- Render line comments **collapsed** (matching the collapsed React JSON-schema editor),
  grouped in a `.line-threads` sub-block under their card, each showing its
  `→ output · line 14` label and pinned snapshot. Reuses the show page's existing
  `line_badge: :collapsed` treatment.
- When **any** change is made anywhere in the form (`Form`'s existing `anyChanges` flag),
  React flags every `CardComments` wrapper as `edited`; CSS then gives
  `.card-comments.edited .line-threads` the amber **Outdated** treatment and reveals an
  "edited — may be outdated" note. This is honest (the snapshots *will* be outdated after
  save) and low effort (one global flag + a CSS rule), instead of per-line snapshot
  re-comparison in JS.

## Components

### Server

1. **`CandidatesController#edit`** loads what `show` already loads: `@categorized_endpoints`,
   `@categorized_entities`, `@comment_threads_by_anchor = @candidate.comment_threads_by_anchor`.

2. **Helper `card_comments_data(endpoints, entities)`** — builds and JSON-encodes the map:
   `{ "verb\x00path" => html, ... }` for endpoints and `{ name => html }` for entities, each
   value produced by `render("comments/card_comments", …)`. Emitted by `_form.html.erb` as a
   `data-comments` attribute on `#react-form`.

3. **Partial `comments/_card_comments.html.erb`** (read-only) — for one endpoint or entity,
   gathers its threads via the existing helpers (`comment_threads_for` for endpoint /
   response / note *whole* threads; `response_output_comments` / `entity_root_comments` for
   line threads) and renders each through `comments/thread` with `read_only: true`. Line
   threads render with `line_badge: :collapsed` inside a `.line-threads` sub-block. Renders
   nothing when the card has no threads.

4. **`read_only` flag** in `comments/_thread.html.erb` + `comments/_thread_body.html.erb` —
   when set, suppresses the reply form, resolve/reopen buttons, and compose affordance. The
   resolved-collapse toggle stays; resolved threads still render (collapsed) for archeology.

### React

5. **`Form.jsx`** — reads a new `comments` dataset prop (JSON), passes it to `EndpointList`
   and `EntityList`, and passes the existing `anyChanges` value down as `edited`.

6. **`CardComments.jsx`** (new) —
   `<div className={edited ? "card-comments edited" : "card-comments"}>`
   `  <div dangerouslySetInnerHTML={{__html: html}} />`
   `</div>`.
   Rendered after each `<Endpoint>` / `<Entity>` in the two lists, looking up `html` by the
   card's original identity. Renders nothing when no blob exists. The `edited` class lives on
   a React-managed wrapper *outside* the injected HTML, so toggling it never re-parses the blob.

### CSS

7. Rule in `app/assets/tailwind/application.css`: `.card-comments.edited .line-threads`
   gets the amber Outdated treatment and reveals its "edited — may be outdated" note
   (hidden otherwise).

## Out of scope (read-only)

- No compose / reply / resolve on the edit page.
- No live weaving of comments into editable line rows (line comments are collapsed under the
  card).
- No quick-access sidebar comment counts (the edit form has no sidebar).
- `new` candidate: loads no comments — the map is naturally empty and React renders nothing.
- The injected HTML is rendered once at page load; it does not live-update as you edit (only
  the global `edited` → Outdated toggle reacts to edits).

## Testing

- **Read-only suppression:** `comments/_card_comments` / `_thread` with `read_only: true`
  renders no reply form, resolve/reopen, or compose (view or request spec on the edit page).
- **`edit` action:** assigns the card-comments map with the expected identity keys and HTML;
  a candidate with no comments yields an empty map.
- React (`CardComments`, injection, edited toggle): manual visual verification in the running
  app — no JS unit framework in this project.

## Staging

Two stages, split so the two independent uncertainties are de-risked separately: the
React/CSS placement, and the server-side read-only rendering. The injection mechanism (view
`data-comments` JSON → React → `dangerouslySetInnerHTML`, keyed by original identity) is real
from Stage 1; Stage 2 only changes where the HTML strings come from.

| # | Stage | Proves |
| --- | --- | --- |
| 1 | **Visuals with static data:** `CardComments.jsx` + wiring into `EndpointList` / `EntityList`, fed a hardcoded sample `data-comments` map emitted from `_form.html.erb` (a few representative thread snippets keyed to real cards on a seeded candidate). Build `.card-comments` placement and the `edited` → `.line-threads` Outdated CSS. | inline placement + edited/Outdated treatment, in isolation from server rendering |
| 2 | **Real data from server:** `edit` action loads the anchor map; `card_comments_data` helper + `comments/_card_comments.html.erb` + the `read_only` flag in `_thread` / `_thread_body`. Swap the static map for the real one. | correct read-only per-card HTML; new candidate comes through empty |

Each stage ends with a user verification checkpoint (visual gate for the UI work).
