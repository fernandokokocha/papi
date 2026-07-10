# Candidate Commenting Stage 9: resolve (close / reopen threads) — Design

> Governing context: the `comment-ui-conventions` memory (binding, includes the Stage 8 rulings) and the Stage 6–8 plans in `docs/superpowers/plans/`. These supersede the original design spec (`2026-07-02-candidate-commenting-design.md`). Stage 8 shipped as `2fbcccd`.

## Goal

Let a thread be **resolved** (marked done) and later **reopened**. A resolved thread stays exactly where it lives but renders **collapsed to a one-line summary**; reopening returns it to full. Resolution is a candidate-author privilege, and replying to a resolved thread auto-reopens it.

## Concept & scope

"Resolved" is a property of a **thread** — i.e. a root comment (`parent_id` nil). Replies are never independently resolved; they inherit nothing about resolution.

Resolution is **orthogonal to Stage 6 placement** (Inlined / Collapsed / Outdated). A resolved thread keeps its placement — inline under its row, below the block, in a pinned strip, or in the candidate-level "Conversation" — and simply substitutes a collapsed summary for its full body. Applies uniformly to every thread kind: line, whole-region, endpoint/entity, and candidate-level.

## Data model

Add two columns to `comments` (edited into the existing comments migration, applied via `bin/rails dev:setup` per the DB-reset workflow — no new migration file):

- `resolved_at:datetime` — presence = resolved.
- `resolved_by_id:integer` — FK to users.

`Comment`:

- `belongs_to :resolved_by, class_name: "User", optional: true`
- `resolved?` → `resolved_at.present?`
- Validation: a reply (`parent_id` present) may not carry `resolved_at` / `resolved_by_id`. Resolution columns are **not** added to `ANCHOR_ATTRIBUTES`, so `inherit_parent_anchor` never copies them onto replies.

## Policy & routes ("keep the door open")

- `CommentPolicy#resolve?` → `@user == @record.candidate.author` (candidate author only). A single method used for **both** resolve and reopen, so widening the rule later is a one-line change with no call-site churn.
- REST as a singular nested resource — resolving *creates* a resolution, reopening *destroys* it:

  ```ruby
  resources :comments, only: [ :create ] do
    resource :resolution, only: [ :create, :destroy ]
  end
  ```

  Path: `/projects/:project_name/candidates/:candidate_name/comments/:comment_id/resolution`.

- `ResolutionsController`:
  - `#create` — resolve the thread (`resolved_at: Time.current, resolved_by: Current.user`).
  - `#destroy` — reopen the thread (clear both columns).
  - Both look the comment up scoped to project + candidate (same strict scoping as `CommentsController`), authorize `resolve?`, and respond with a turbo-stream that **replaces the whole thread** (`dom_id(comment)`) with its freshly-rendered state.

## Rendering — the collapsed summary

`_thread` branches on `comment.resolved?`:

- **Resolved:** a one-line summary strip on top:
  - Left: `✓ Resolved by <email> · <N> comment(s)` — clickable to expand; hover `title` carries who resolved and when. `<N>` = 1 (root) + reply count.
  - Right: the existing placement badge (Inlined / Collapsed / Outdated) if this is a line thread, then a **Reopen** button (candidate author only).
  - The full thread body (comment, replies, reply form, Resolve button) renders **but `hidden`**; a small `resolved-thread` Stimulus controller reveals it on click. Expanding lets you read replies and reply (which auto-reopens — see below).
- **Open:** as today, plus a **Resolve thread** button in the thread **footer** (near the reply form, GitHub-style; candidate author only).

Notes:

- Resolve/Reopen are `button_to` forms opted into Turbo per-element (Turbo Drive stays off, per the `turbo-drive-off` convention).
- Threads live inside `.anchor-strip`, which comment mode ignores, so the buttons are clickable whether comment mode is on or off. Resolve is **not** tied to comment mode.
- The summary strip carries `anchor-strip` like the rest of the comment surface.

## The `line_badge` carry (Ruling A — accepted)

When resolve / reopen / reply re-renders a thread via turbo-stream, the server does not know a line thread's current placement badge — Inlined vs Collapsed depends on the client's expanded state, which is client-only. So each of the resolve / reopen / reply forms carries the **current `line_badge` as a hidden field** (the view knows it at render time), and the controller passes it back into the `_thread` re-render — the same discipline as the existing `expanded` hidden field. Non-line threads carry nothing → no badge, as today.

This keeps the placement badge correct across resolve/reopen/reply without the server recomputing placement.

## Auto-reopen on reply

- `Comment` gains `after_create :reopen_parent, if: :reply?`, clearing the parent's `resolved_at` / `resolved_by_id`.
- The reply-create turbo-stream branches:
  - If the reply **reopened** a resolved parent → `replace` the whole parent thread (`dom_id(parent)`), rendered open, with `line_badge` from the reply form's hidden field.
  - Otherwise → today's behavior unchanged (append the reply into `dom_id(parent, :replies)`, reset the reply form).

## Deliberate non-changes

- **Sidebar 💬 counts stay untouched.** `comment_threads_by_anchor` / `comment_count_badge` / `comment_sidebar_count` count all threads regardless of resolution. No counting code changes. (User ruling: badge = total conversations.)
- **Outdated interplay:** resolution and Outdated coexist and are not special-cased. A resolved + outdated line thread shows the collapsed summary with its amber **Outdated** badge on the strip; reopening returns it to the full outdated render (below-block, snapshot + amber badge, per Stage 6).
- **Version pages stay byte-clean.** Resolve/Reopen controls render only in commentable context (`@candidate` present), like every other comment affordance; version pages render no threads at all.

## Testing

- **Model:** `resolved?`; reply-can't-be-resolved validation; `reopen_parent` callback clears the parent on reply.
- **Policy:** candidate author → `resolve?` true; another group member → false.
- **Requests:**
  - Resolve turbo-stream replaces the thread with the collapsed summary (and correct `line_badge`).
  - Reopen turbo-stream replaces it back to full.
  - Reply on a resolved thread auto-reopens (parent's `resolved_at` cleared) and the stream replaces the parent thread open.
  - Non-candidate-author is forbidden from resolve/reopen.
  - Sidebar badge count is unchanged by resolving.
  - Version-page non-leak: no resolve/reopen controls.

## Accepted / out of scope

- Resolution has no per-reply granularity — it's a whole-thread state.
- No "resolved" filter/toggle in the toolbar (threads stay in place collapsed; hiding them was considered and rejected in favor of collapse-to-summary).
- No audit trail beyond `resolved_by` / `resolved_at` (last resolver wins; reopening clears both).
- The `resolved-thread` expand is client-only, non-persisted (like other local reveal state).
