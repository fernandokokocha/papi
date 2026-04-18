# Changed endpoint / entity signal — design

## Problem

A version diff view shows endpoints and entities in four conceptual states: unchanged, changed, added, removed. Today the code models only three: `added`, `removed`, and `existing` — where `existing` silently covers both "identical content" and "content differs". Added and removed stand out visually (emerald and red headers, sidebar tints). Changed blends in with unchanged: readers have to scan the per-line diff markers inside each card to notice that anything is different.

Goal: make "changed" a distinct, scannable state on both the card and the sidebar, without disturbing how added/removed/unchanged look today.

## Scope

- Introduce a fourth annotation: `changed`. Split today's `existing` into `unchanged` (identical pair) and `changed` (pair with any diff).
- Apply an amber treatment to changed endpoints and entities in the card header and the sidebar entry.
- Do not change the per-line diff rendering inside cards — that's where the *what-changed* detail lives.
- Do not change selection/target highlight styling in this change (see "Known follow-up").
- Do not propagate entity changes to endpoints that reference them.
- Do not reorder the sidebar by state.

## What counts as "changed"

Any diff in any field counts. For an endpoint: note, responses, output, or output-for-errors differs. For an entity: the parsed JSON structure differs. A note-only change counts just as much as a schema change — no gradations, no badges describing the kind of change.

## Detection

Add equality-style predicates on the models:

- `Endpoint#differs_from?(previous)` — builds the same diffs the view would (`DiffText::FromNotes`, `DiffResponses::FromResponses`, `Diff::FromValues` for output and output-for-errors) and returns true if any diff line has a change other than no-change.
- `Entity#differs_from?(previous)` — builds `Diff::FromValues` over `parsed_root` and returns true if any line differs.

`Version::CategorizeByName` changes its "found in previous" branch: after setting `previous`, it sets annotation to `"unchanged"` or `"changed"` based on `differs_from?`. The `"existing"` annotation value disappears.

Cost is small — N is tiny in practice and the diff machinery is already used eagerly by the view.

## Visual treatment — card

Amber replaces the neutral header color on changed cards. Both sides of the split diff (previous and current) get amber, because the amber is the *state* of the pair, not of one column.

**Endpoint changed card** (`_endpoint_diff.html.erb`):
- Header background: `bg-amber-600` (replaces `bg-sky-900`). Text stays `text-white`.
- Card border: `border-amber-200` (replaces `border-gray-200`).
- Section-separator rows inside the body stay their current neutral gray.

**Entity changed card** (`_entity_diff.html.erb`):
- Header background: `bg-amber-600` (replaces `bg-violet-800`). Text stays `text-white`.
- Card border: `border-amber-200` (replaces `border-gray-200`).

Unchanged cards render exactly as `existing` does today — sky-900 / violet-800 headers, no border accent. The existing `_endpoint_diff` and `_entity_diff` partials already render whatever the diff produces, so no new partials are needed. We pass the annotation in and switch header / border classes conditionally on `annotation == "changed"`.

## Visual treatment — sidebar

Extend the tint map in `_endpoints_and_entities.html.erb`:

```ruby
tint = {
  "added"   => "bg-emerald-50 text-emerald-700 font-semibold",
  "removed" => "bg-red-50 text-red-700 font-semibold line-through",
  "changed" => "bg-amber-50 text-amber-700 font-semibold",
}[item.annotation] || "text-gray-700"
```

`unchanged` falls through to the default neutral gray — identical to how `existing` renders today.

Sort order is unchanged: items stay sorted by `sort_name`; we do not group by state.

## Files touched

- `app/services/version/categorize_by_name.rb` — emit `"unchanged"` / `"changed"` instead of `"existing"`, based on `differs_from?`.
- `app/models/endpoint.rb` — add `differs_from?(previous)`.
- `app/models/entity.rb` — add `differs_from?(previous)`.
- `app/views/versions/_endpoints_and_entities.html.erb` — replace `"existing"` branch with branches for `"unchanged"` and `"changed"`; pass annotation into the card partials; update sidebar tint map.
- `app/views/endpoints/_endpoint_diff.html.erb` — accept annotation; switch header background (`bg-sky-900` ↔ `bg-amber-600`) and border color conditionally.
- `app/views/versions/_entity_diff.html.erb` — accept annotation; switch header background (`bg-violet-800` ↔ `bg-amber-600`) and border color conditionally.
- `app/controllers/design_preview_controller.rb` — add an "unchanged" endpoint pair (identical previous/current) and an "unchanged" entity pair alongside the existing diff/added/removed fixtures. The existing `diff_endpoints` / `diff_entities` fixtures already differ between previous and current, so they become the "changed" examples.
- `app/views/design_preview/show.html.erb` — render the changed endpoint/entity cards (existing diff fixtures, now passed `annotation: "changed"`) and the new unchanged examples (`annotation: "unchanged"`) so both states are visible side by side.

No automated tests — visual regression is verified by eye via `/design_preview`.

## Known follow-up (deferred)

The `target:` selection highlight uses amber today (`bg-amber-100 ring-amber-500` in `_endpoints_and_entities.html.erb`). With amber now also signalling "changed", a selected changed card shows amber-on-amber and the two states merge visually. We accept this collision for this change; picking a new selection accent (likely sky or a neutral dark ring) is the next task.
