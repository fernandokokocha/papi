# Version ⇄ Candidate navigation & projects-page redesign

**Date:** 2026-07-11
**Status:** Approved (design)

## Problem

Two related gaps in moving between a version and the candidate that produced it:

1. From a **version** show page there is no way to jump to its **candidate** — where the
   comments / conversation live (you want to preview the comments from the version).
2. From a **merged candidate** there is no way to jump to the **version** it became.
3. The projects index renders **two independent columns** (Versions | Candidates) with no
   visible relationship between them, even though a version *is* a merged candidate.

## Domain facts (as-is)

- `Version belongs_to :candidate` (required) — every version was produced by a candidate.
- On merge, `Candidate::Merge` promotes the candidate's `latest_version` into a project
  version (sets `project`, a new `order`, and a `v#` name). So a merged candidate's
  `latest_version` *is* the resulting project version.
- Open/rejected candidates have no promoted version.
- Only one candidate can be `open` at a time (`Project#can_create_candidate?`).
- `Project#latest_version` is the current version (highest `order`).

## Part 1 — Cross-navigation buttons

### Version → candidate
`app/views/versions/show.html.erb`, header button group. Always shown (a version always
has a candidate):

> **View candidate → `rc5`** → `project_candidate_path(@project.name, @version.candidate.name)`

### Candidate → version
`app/views/candidates/show.html.erb`. Shown **only when the candidate is `merged`**
(open state already renders Edit/Reject/Merge; rejected has no version):

> **View version → `v3`** → `project_version_path(@project.name, @candidate.promoted_version.name)`

(`Candidate#promoted_version` is introduced in Part 2 and reused here.)

Label format: `View candidate → <name>` / `View version → <name>`, styled as a secondary
button (`bg-white text-gray-700 border border-gray-300 hover:bg-gray-50`).

## Part 2 — Projects page redesign

Each project card's two-column grid is replaced by **one chronological history** of the
project, rendered in **two view modes** toggled by a single page-level control.

### Data

Add `Project#history`:

```ruby
def history
  candidates.includes(:author, :decided_by, :versions, :comments).order(order: :desc)
end
```

Per candidate the views derive:

- **promoted version** — the version the candidate became, or none. Add
  `Candidate#promoted_version` returning `latest_version` when `merged?`, else `nil`
  (uses the already-loaded `versions` association — pick the max `order` in Ruby to avoid
  a fresh query).
- **is current** — `promoted_version == project.latest_version` (compare by id).
- state (`aasm_state`), proposer (`author`), decider (`decided_by`), comment count
  (`comments.size` on the loaded association — includes replies), date (`created_at`).

### Views

- `app/views/projects/_history_table.html.erb` — columns: Version / Candidate / State /
  Proposed / Decided / 💬 / Date. Newest first. Current-version row tinted (`bg-sky-50`).
  Rejected rows have an empty Version cell.
- `app/views/projects/_history_timeline.html.erb` — a chronological rail. Merged
  candidates sit on a solid version node (`v#`); the current version node is enlarged and
  haloed; rejected candidates get a small hollow ✕ node but keep their chronological
  position; the open candidate pulses at the top. Each entry shows candidate name, state
  badge, `v# ← rcN` mapping, proposer/decider, comment count, date.

Both partials take a `project` local and render for **every** card; the inactive one is
hidden via CSS.

### Toggle

- New Stimulus controller `view_toggle` on a wrapper around the whole projects list.
- Segmented pill in the page header (`Table` | `Timeline`), Table active by default.
  Styling: `inline-flex` pill, active segment white on `bg-slate-100` track, matching the
  White & Sky palette.
- Clicking a segment sets `data-view="table" | "timeline"` on the wrapper and writes the
  choice to `localStorage`; on `connect` the controller restores it.
- CSS drives visibility: `[data-view="table"] .timeline-view { display: none }` and
  `[data-view="timeline"] .table-view { display: none }`. No server round-trip.

### Page header

`app/views/projects/index.html.erb` header keeps the group title + New project button and
adds the segmented control on the right.

## Testing

- **Model:** `Project#history` returns candidates newest-first; `Candidate#promoted_version`
  returns the version only when merged (nil for open/rejected).
- **Request:** version show links to its candidate; merged candidate show links to its
  version; open and rejected candidate show render no version link.
- **Toggle:** both partials present in the rendered projects index; interactive
  table⇄timeline switch verified manually (no JS unit framework in this project).

## Out of scope

- Comment counts are totals (root + replies); no per-thread breakdown.
- No collapsing/filtering of rejected candidates beyond the timeline's visual
  de-emphasis.
- No pagination of history.
