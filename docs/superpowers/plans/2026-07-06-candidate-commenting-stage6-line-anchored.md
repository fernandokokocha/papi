# Candidate Commenting Stage 6 (REVISED): inline line comments in the output/root tree + whole-response Outdated (render-only) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render existing line-anchored comment threads **inline, directly under the rendered row** they pin to inside a response output / entity root JSON tree; when placement can't be trusted (the block is collapsed, or the whole response output has changed since pin time) fall back to a labeled block **below the response** showing the stored snapshot.

**Architecture:** A line comment stores `line` = the row index in the block's **expanded** rendered tree, and `anchor_snapshot` = the **whole** block output text at pin time (no per-line snapshot). Freshness is a whole-block compare: `anchor_snapshot == current_output`. `specs/_json` (the single partial that renders every output/root tree) gains an optional `comments_by_line:` map and interleaves each thread right after its row. Each render site partitions a block's line comments into **inline** (only when the block is expanded AND fresh) and **below** (everything else), passing the inline map into `specs/_json` and rendering the below set in a labeled fallback block. Notes are no longer line targets.

**Tech Stack:** Rails 8, Hotwire (Turbo + Stimulus), Tailwind CSS v4, RSpec, FactoryBot.

## Why this supersedes the earlier Stage 6 (read before starting)

An earlier Stage 6 (strip-below-block, per-line raw-text snapshot, `CommentAnchor#resolve_against`, note line comments) was implemented and **staged but never committed** (HEAD is still 63c6e8c). At the visual gate the design changed. This plan **replaces** that staged work. Concretely, this plan **removes**:

- `CommentAnchor#resolve_against` and its private helpers `target_in` / `find_endpoint` / `current_text_for` / `block_text` (keep `verb_word`, used by `label`), plus their specs.
- `app/views/comments/_line_threads.html.erb` (strip partial) and its six `render "comments/line_threads"` call sites in `_endpoint_diff`, `_endpoint_new`, `_endpoint_removed`, `specs/_responses`, `_endpoints_and_entities`.
- The helper `line_comment_threads_for`.
- The Stage-6 note/whole-single-line fixtures and the earlier line fixtures (re-authored here).

It **keeps** `CommentAnchor#snapshot` + `#label` and `Comment#anchor` passing `anchor_snapshot`.

The work is staged, not committed, so edit forward — no git surgery needed.

## Global Constraints

- **Render-only.** No write path, no line-picker, no resolve. `line` and `anchor_snapshot` are set only by fixtures. Creation (including translating a collapsed pick to the canonical expanded index) is Stages 7–8.
- **Snapshot = whole block output** (e.g. `"{total:number,items:[User]}"`), not a single line. **Outdated = `anchor_snapshot != current_output`** (fires on any output edit, incl. whitespace/reorder — accepted/sacrificable).
- **`line` = row index in the block's EXPANDED rendered tree** (the `Diff::Lines` that `specs/_json` iterates; 0-based). It is used **only** for inline placement when the block is expanded and fresh; otherwise ignored.
- **Placement rule** (one rule for both "can't trust it" reasons):

  | Block state | Where a line comment renders |
  | --- | --- |
  | Expanded + fresh (`snapshot == current_output`) | **Inline**, under its row |
  | Collapsed (but fresh) | **Below** the block, label only (no Outdated) |
  | Outdated (`snapshot != current_output`, any expand state) | **Below** the block, label + snapshot + amber **Outdated** badge |

  Entity roots are never collapsible → they're always "expanded": fresh → inline, outdated → below.
- Comments never render on version pages. All lookups read `@comment_threads_by_anchor`, nil outside candidate context → `[]` → nothing renders. No explicit `@candidate` gate needed in the new helpers.
- Tailwind classes must be **complete literal strings**. White & Sky palette; Outdated amber (`bg-amber-50 text-amber-700 border-amber-200`), consistent with the "changed" tint. Snapshot quote uses the mono treatment (`bg-gray-100 text-gray-800 font-mono`). Double quotes, 2-space indent.
- Reuse conventions from the `comment-ui-conventions` memory: threads keep the sky left-accent identity; new comment surfaces carry `anchor-strip`; no part chips.
- No TDD-first ordering: specs written after/alongside impl; no RED "verify it fails" steps.
- Git: do NOT commit or branch. Stage with `git add -A`; single Stage 6 commit proposed to the user at the end. Pause at the Task 2 visual gate.

## Reference: real expanded rows (verified via `bin/rails runner`)

`GET /users` 200 output `"{total:number,items:[User]}"` renders (expanded) as:

```
[0] {
[1] total: number
[2] items:
[3] [
[4] User
[5] ]
[6] }
```

`User` entity root `"{id:number,email:string,name:string,avatar_url:string}"` renders as:

```
[0] {
[1] id: number
[2] email: string
[3] name: string
[4] avatar_url: string
[5] }
```

These indices are for the **isolated** `parsed_output.to_diff(:no_change)`. On the candidate page the block is rendered through the **diff** pipeline (`output_diff.after` for responses, `diff.after` for entities). For a block whose output is **unchanged** between base and current, the after-side rows equal the isolated `to_diff` above; for a changed block, diff markers/blank-alignment rows can shift indices. **The fixture author MUST confirm the real after-side index** (Task 2 Step 6) with a runner before setting `line`.

---

### Task 1: Trim `CommentAnchor` to `label` + `snapshot` (remove `resolve_against`)

`resolve_against` implemented the old per-line raw-text drift model, which this design drops (freshness is now a whole-block compare done at render time). Remove it and its raw-text helpers and specs; keep `snapshot` (used by the render) and `label`.

**Files:**
- Modify: `app/models/comment_anchor.rb`
- Modify: `spec/models/comment_anchor_spec.rb`

**Interfaces:**
- Consumes: nothing new.
- Produces: `CommentAnchor` retains `key`, `errors`, `from_params`, `to_columns`, `dom_id`, `snapshot` (reader + ctor kwarg), `label`, and the private `verb_word`. `resolve_against`, `target_in`, `find_endpoint`, `current_text_for`, `block_text` are gone. `Comment#anchor` is unchanged (still passes `snapshot: anchor_snapshot`). Task 2 reads `comment.anchor.label` and `comment.anchor_snapshot` directly.

- [ ] **Step 1: Remove `resolve_against` + its raw-text helpers** — in `app/models/comment_anchor.rb`, delete the `resolve_against` public method and the private `target_in`, `find_endpoint`, `current_text_for`, `block_text` methods. Keep the `private` keyword and `verb_word` (still used by `label`). Keep `label`, `snapshot`, and everything above `private`. The private section should end up as just:

```ruby
  private

  def verb_word
    key = Endpoint.http_verbs.key(endpoint_http_verb)
    key && Endpoint::VERB_TRANSLATIONS[key.to_sym]
  end
```

- [ ] **Step 2: Remove the `resolve_against` specs** — in `spec/models/comment_anchor_spec.rb`, delete the entire `describe "#resolve_against"` block (the one that builds a `version`/`endpoint`/`response` and asserts fresh/drifted/gone). Keep the `describe "#label"` block and all pre-existing examples (`#key`, `#errors`, `#from_params`, `#to_columns`, `#dom_id`).

- [ ] **Step 3: Run the model specs**

Run: `bundle exec rspec spec/models/comment_anchor_spec.rb spec/models/comment_spec.rb`
Expected: green (label + all pre-existing examples; the removed drift examples are gone).

- [ ] **Step 4: Checkpoint** — report results. No commit. Rendering is Task 2.

---

### Task 2: Inline rendering in the tree + below-block fallback + fixtures

Add two lookups, make `specs/_json` interleave inline threads, add an inline thread partial and a below-block fallback partial, wire the response + entity render sites (removing the old strip sites), re-author the fixtures against real indices, and gate visually.

**Files:**
- Modify: `app/helpers/comments_helper.rb` (replace `line_comment_threads_for` with `response_output_comments` + `entity_root_comments` + `partition_line_comments`)
- Modify: `app/views/specs/_json.html.erb` (interleave)
- Create: `app/views/comments/_inline_line_comment.html.erb`
- Modify: `app/views/comments/_line_threads.html.erb` → repurpose as the **below-block** fallback (rename usage; see Step 4)
- Modify: `app/views/endpoints/_response_cell.html.erb` (accept + pass `comments_by_line`)
- Modify: `app/views/endpoints/_endpoint_diff.html.erb` (response loop: partition, pass inline map, render below block; remove old strip render)
- Modify: `app/views/specs/_responses.html.erb` (same, for new/removed cards; remove old strip render)
- Modify: `app/views/endpoints/_endpoint_new.html.erb`, `app/views/endpoints/_endpoint_removed.html.erb` (remove old note strip renders)
- Modify: `app/views/versions/_endpoints_and_entities.html.erb` (entity: partition, render below block; remove old strip render), `app/views/versions/_entity_diff.html.erb` (after side: pass inline map), `app/views/versions/_entity_added.html.erb` (pass inline map)
- Modify: `test/fixtures/comments.yml`
- Modify: `spec/requests/candidates_requests_spec.rb`, `spec/requests/versions_requests_spec.rb`

**Interfaces:**
- Consumes: `@comment_threads_by_anchor`, `comment.anchor.label`, `comment.anchor_snapshot`, `comments/_thread`, `render_type` (existing helper), the `expanded` local already threaded through the endpoint diff partials.
- Produces:
  - `response_output_comments(endpoint, response_code)` / `entity_root_comments(entity)` → line-anchored root `Comment`s for that block (scope response part output / scope entity part root, `line` set), sorted by `[line, created_at]`; `[]` off-candidate.
  - `partition_line_comments(comments, current_text, expanded:)` → `{ inline: { Integer => [Comment] }, below: [Comment] }`. `inline` = comments where `expanded && anchor_snapshot == current_text`, grouped by `line`; `below` = the rest (order preserved).
  - `specs/_json` local `comments_by_line:` (Hash, default `{}`): after each row `i`, renders `comments_by_line[i]` via `comments/_inline_line_comment`.
  - `comments/_inline_line_comment` — local `comment:`; the thread indented under its row.
  - `comments/_line_threads` (repurposed) — locals `comments:`, `current_text:`, `wrapper_class:`; the below-block fallback (label; snapshot + amber Outdated only when `anchor_snapshot != current_text`).

- [ ] **Step 1: Replace the helper** — in `app/helpers/comments_helper.rb`, delete `line_comment_threads_for` and add:

```ruby
  # Output-line root threads for one response (scope response, part output, line set),
  # sorted by [line, created_at]. [] outside candidate context.
  def response_output_comments(endpoint, response_code)
    return [] unless @comment_threads_by_anchor

    verb = Endpoint.http_verbs[endpoint.http_verb]
    @comment_threads_by_anchor.flat_map do |(scope, path, v, _name, code, part, line), threads|
      next [] unless scope == "response" && part == "output" && !line.nil?
      next [] unless path == endpoint.path && v == verb && code == response_code
      threads
    end.sort_by { |c| [ c.line, c.created_at ] }
  end

  # Root-line root threads for one entity (scope entity, part root, line set).
  def entity_root_comments(entity)
    return [] unless @comment_threads_by_anchor

    @comment_threads_by_anchor.flat_map do |(scope, _path, _v, name, _code, part, line), threads|
      next [] unless scope == "entity" && part == "root" && !line.nil?
      next [] unless name == entity.name
      threads
    end.sort_by { |c| [ c.line, c.created_at ] }
  end

  # Split a block's line comments: inline (only when expanded AND fresh vs the whole
  # block text), keyed by row index; below (everything else), in order.
  def partition_line_comments(comments, current_text, expanded:)
    inline, below = comments.partition { |c| expanded && c.anchor_snapshot == current_text }
    { inline: inline.group_by(&:line), below: below }
  end
```

- [ ] **Step 2: `specs/_json` interleaves inline threads** — rewrite `app/views/specs/_json.html.erb`:

```erb
<% comments_by_line = local_assigns[:comments_by_line] || {} %>
<% if diff.empty? %>
  -
<% else %>
  <% diff.each.with_index do |diff_line, i| %>
    <div class="line <%= diff_line.change %>"><%= render_type(diff_line) %></div>
    <% (comments_by_line[i] || []).each do |comment| %>
      <%= render "comments/inline_line_comment", comment: comment %>
    <% end %>
  <% end %>
<% end %>
```

Every current caller passes only `diff:`, so `comments_by_line` defaults to `{}` → byte-identical output for them (version pages, base columns, note-less trees).

- [ ] **Step 3: Inline thread partial** — create `app/views/comments/_inline_line_comment.html.erb`:

```erb
<div class="my-1 ml-4 border-l-2 border-l-sky-200 pl-3">
  <%= render "comments/thread", comment: comment %>
</div>
```

- [ ] **Step 4: Repurpose `_line_threads` as the below-block fallback** — replace `app/views/comments/_line_threads.html.erb` entirely:

```erb
<% if comments.any? %>
  <div class="anchor-strip <%= local_assigns[:wrapper_class] %> flex flex-col gap-2">
    <% comments.each do |comment| %>
      <% outdated = comment.anchor_snapshot != current_text %>
      <div class="flex flex-col gap-1">
        <div class="flex items-center gap-2">
          <span class="font-mono text-xs text-gray-500"><%= comment.anchor.label %></span>
          <% if outdated %>
            <span class="shrink-0 bg-amber-50 text-amber-700 border border-amber-200 text-[10px] font-semibold px-2 py-0.5 rounded-full">Outdated</span>
          <% end %>
        </div>
        <% if outdated && comment.anchor_snapshot.present? %>
          <div class="bg-gray-100 text-gray-800 font-mono text-xs px-2 py-1 rounded border border-gray-200 whitespace-pre-wrap"><%= comment.anchor_snapshot %></div>
        <% end %>
        <%= render "comments/thread", comment: comment %>
      </div>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 5: Wire the render sites** (remove every old `render "comments/line_threads"` strip call as you go; the below-block now renders `comments/line_threads` with the new `comments:`/`current_text:` locals).

**`app/views/endpoints/_response_cell.html.erb`** — thread the inline map into the JSON render. Change the two `render "specs/json", diff: body`-style calls (the wholesale `node.to_diff` body and the `output_diff` body both flow through the single `render "specs/json", diff: body` near the end) to:

```erb
      <div class="font-mono text-xs text-gray-800 mt-1"><%= render "specs/json", diff: body, comments_by_line: local_assigns[:comments_by_line] || {} %></div>
```

**`app/views/endpoints/_endpoint_diff.html.erb`** — in the responses loop, replace the old `render "comments/line_threads"` (the strip after the response cells) with partition + inline pass + below block:

```erb
      <% resp_record = endpoint.responses.find { |r| r.code == line.code } %>
      <% resp_line_comments = partition_line_comments(response_output_comments(endpoint, line.code), resp_record&.output, expanded: expanded) %>
      <%= render "endpoints/response_cell", line: line, side: :before, region_attr: comment_region_attr(resp_anchor) %>
      <%= render "endpoints/response_cell", line: line, side: :after, curl_verb: endpoint.verb, curl_path: endpoint.path, region_attr: comment_region_attr(resp_anchor), comments_by_line: resp_line_comments[:inline] %>
      <%= render "comments/anchor_region", anchor: resp_anchor, threads: comment_threads_for("response", endpoint: endpoint, response_code: line.code), wrapper_class: line.after_present? ? "col-start-2" : "col-start-1" %>
      <%= render "comments/line_threads", comments: resp_line_comments[:below], current_text: resp_record&.output, wrapper_class: line.after_present? ? "col-start-2" : "col-start-1" %>
```

(The inline map goes to the **after** cell only. `resp_anchor` and the existing `anchor_region` for whole/note/output non-line threads are unchanged.)

**`app/views/specs/_responses.html.erb`** (new/removed single-column cards) — same shape; the present side here is whichever `side` the card renders. Replace the old strip render with:

```erb
    <% resp_record = endpoint.responses.find { |r| r.code == line.code } %>
    <% resp_line_comments = partition_line_comments(response_output_comments(endpoint, line.code), resp_record&.output, expanded: expanded) %>
    <%= render "endpoints/response_cell", line: line, side: side, curl_verb: local_assigns[:curl_verb], curl_path: local_assigns[:curl_path], region_attr: comment_region_attr(resp_anchor), comments_by_line: resp_line_comments[:inline] %>
    <%= render "comments/anchor_region", anchor: resp_anchor, threads: comment_threads_for("response", endpoint: endpoint, response_code: line.code), wrapper_class: "" %>
    <%= render "comments/line_threads", comments: resp_line_comments[:below], current_text: resp_record&.output, wrapper_class: "" %>
```

`specs/_responses` needs `expanded` — it is already rendered from `_endpoint_new`/`_endpoint_removed`, which have `expanded` in scope; pass `expanded: expanded` in those two `render "specs/responses", ...` calls (add the local).

**`app/views/endpoints/_endpoint_new.html.erb`** and **`app/views/endpoints/_endpoint_removed.html.erb`** — delete the old `render "comments/line_threads"` note-strip call (the note is no longer a line target). Add `expanded: expanded` to their `render "specs/responses", ...` call.

**`app/views/versions/_endpoints_and_entities.html.erb`** — in the entity branch, replace the old strip render after the entity diff with the below block (entities are always expanded → `expanded: true`):

```erb
            <% entity_line_comments = partition_line_comments(entity_root_comments(entity), entity.root, expanded: true) %>
            <%= render "comments/anchor_region", anchor: entity_anchor, threads: comment_threads_for("entity", entity: entity), wrapper_class: entity.annotation == "removed" ? "mt-3 w-1/2 pr-1" : "mt-3 w-1/2 ml-auto pl-1" %>
            <%= render "comments/line_threads", comments: entity_line_comments[:below], current_text: entity.root, wrapper_class: entity.annotation == "removed" ? "mt-3 w-1/2 pr-1" : "mt-3 w-1/2 ml-auto pl-1" %>
```

and pass the inline map into the entity tree. The tree renders in `versions/_entity_diff` (after side, line 19) and `versions/_entity_added` (line 8). Compute the inline map where `entity` is in scope and pass it as a local into those partials, then into their `render "specs/json"`:

- In `_endpoints_and_entities`, when rendering `entity_diff` / `entity_added`, add `comments_by_line: entity_line_comments[:inline]` as a local (move the `entity_line_comments` assignment above those renders).
- In `versions/_entity_diff.html.erb` line 19 (the **after** side): `<%= render "specs/json", diff: diff.after, comments_by_line: local_assigns[:comments_by_line] || {} %>`. Leave the before side (line 11) untouched.
- In `versions/_entity_added.html.erb` line 8: `<%= render "specs/json", diff: diff, comments_by_line: local_assigns[:comments_by_line] || {} %>`.
- `_entity_removed` (removed entity, before side) keeps threads below only — pass nothing to its `specs/json`.

- [ ] **Step 6: Author fixtures against REAL indices** — first confirm the real after-side row index for each target with a runner (the candidate page for rc4 diffs base vs current):

```bash
bin/rails runner '
cand = Candidate.find_by(name: "rc4"); v = cand.latest_version; pv = cand.base_version
ep = v.endpoints.find_by(path: "/users", http_verb: 0)
pep = pv.endpoints.find_by(path: "/users", http_verb: 0)
d = DiffResponses::FromResponses.new(pep.responses, ep.responses, expanded: true)
line = d.lines.find { |l| l.code == "200" }
puts "GET /users 200 current output=#{ep.responses.find { |r| r.code == "200" }.output.inspect}"
line.output_diff.after.lines.each_with_index { |l,i| puts "  after[#{i}] #{l.whole_line.inspect}" }
ent = v.entities.find_by(name: "User"); pent = pv.entities.find_by(name: "User")
puts "User current root=#{ent.root.inspect}"
Diff::FromValues.new(pent.parsed_root, ent.parsed_root).after.lines.each_with_index { |l,i| puts "  root[#{i}] #{l.whole_line.inspect}" }
'
```

Then append to `test/fixtures/comments.yml` (candidate4 = rc4). Set each `line` to the **after-side index** the runner prints for the intended row, and each fresh `anchor_snapshot` to the **exact current whole output** the runner prints; make the outdated one a plausible older whole output. Author (adjust `line`/snapshots to the runner output):

```yaml
c4_users_list_200_output_line_fresh:
  candidate: candidate4
  author: one
  body: "Do clients page through items[] or is total the source of truth?"
  scope: response
  endpoint_path: /users
  endpoint_http_verb: 0
  response_code: "200"
  part: output
  line: 4                 # the "User" row — CONFIRM against runner after-side index
  anchor_snapshot: "{total:number,items:[User]}"   # == current output → fresh → inline
  created_at: 2025-04-03 12:00:00

c4_users_list_200_output_line_outdated:
  candidate: candidate4
  author: two
  body: "When I flagged this, the response was still a bare [User] array."
  scope: response
  endpoint_path: /users
  endpoint_http_verb: 0
  response_code: "200"
  part: output
  line: 1                 # was the array row in the old shape
  anchor_snapshot: "[User]"                         # != current output → outdated → below
  created_at: 2025-04-03 12:30:00

c4_user_entity_root_line_fresh:
  candidate: candidate4
  author: two
  body: "name is required — worth documenting the max length here."
  scope: entity
  entity_name: User
  part: root
  line: 3                 # the "name: string" row — CONFIRM against runner
  anchor_snapshot: "{id:number,email:string,name:string,avatar_url:string}"  # == current → fresh → inline
  created_at: 2025-04-03 13:00:00

c4_user_entity_root_line_outdated:
  candidate: candidate4
  author: one
  body: "Back when I commented, avatar_url wasn't on User yet."
  scope: entity
  entity_name: User
  part: root
  line: 3
  anchor_snapshot: "{id:number,email:string,name:string}"  # != current → outdated → below
  created_at: 2025-04-03 13:30:00
```

- [ ] **Step 7: Reseed + candidate request spec** — `bin/rails dev:setup`, then add to `spec/requests/candidates_requests_spec.rb` inside the `describe "#show inline comment threads"` group a FactoryBot-built example (fixtures are not loaded by RSpec — build via controller POST + `candidate.comments.create!`, mirroring the existing anchored-threads example). Create a `/users` GET candidate with a `200` response whose `output` is `"{total:number,items:[User]}"` (plus a `User` entity so `JSONSchemaParser` resolves it), one output line comment with `anchor_snapshot` == that output (fresh) and one with a mismatched snapshot (outdated). Because the card renders **collapsed by default**, both fresh and outdated render **below** on first load, so assert the below-block markers:

```ruby
      expect(response.body).to include("GET /users → 200 → output · line 4")   # label present
      expect(response.body).to include("Outdated")                              # the mismatched-snapshot one
      expect(response.body).to include("[User]")                                # its snapshot shown
```

(The inline path is exercised at the visual gate by expanding; a request spec can't easily assert row-interleave without reproducing the diff pipeline.)

- [ ] **Step 8: Version-page non-leak spec** — in `spec/requests/versions_requests_spec.rb`, keep the existing example that seeds a line-anchored comment on the merged candidate and asserts `not_to include("Outdated")` / `not_to include("· line")` on the version page. Update its seeded comment to the new model (`part: output`, `line: <n>`, `anchor_snapshot:` a whole output that mismatches, so it WOULD show "Outdated"/label if it leaked). Confirm the assertions still pass (version page renders no candidate comments).

- [ ] **Step 9: Full verification**

Run: `bundle exec rspec` — entire suite green.
Run: `bin/rubocop` — no offenses.
Run: `bin/rails tailwindcss:build` — pick up any new class combos.

- [ ] **Step 10: VISUAL CHECKPOINT (user gate)** — on rc4's candidate page:
  - `GET /users` 200 **collapsed** (default): both line comments show **below** the response — the fresh one as a plain labeled `→ output · line 4` block, the outdated one with the amber **Outdated** badge and its `[User]` snapshot.
  - **Expand** `GET /users`: the fresh comment jumps **inline**, rendered directly under the `User` row in the tree; the outdated one stays below (snapshot shown). Collapse again → it returns below.
  - `User` entity (always expanded): the fresh root comment renders **inline** under the `name: string` row; the outdated one renders **below** with its old-root snapshot + Outdated.
  - Threads keep sky identity; reply works; version page `v4` shows no labels/snapshots/Outdated/inline threads.
  - Tune inline indentation, below-block placement, label wording, snapshot styling per feedback. No commit yet.

- [ ] **Step 11: Propose the commit** — suggest `Add candidate commenting Stage 6: inline line comments + whole-response Outdated` and commit **only on the user's go-ahead**.

---

## Self-review notes (traceability)

- **Inline under the rendered row** (user's end-result) — `specs/_json` interleave (Step 2) + inline partial (Step 3); wired at the after-side response/entity render sites (Step 5).
- **Snapshot = whole output, Outdated = whole-block compare** (user ruling) — `partition_line_comments` (Step 1) + the below-block `outdated = anchor_snapshot != current_text` (Step 4).
- **Collapsed → below, one fallback with outdated** (user ruling) — `partition_line_comments(expanded:)` + the placement table; collapsed responses render below on load (Step 7 asserts this).
- **No auto-expand, no two comment sets, no per-line snapshot math** — `line` stored once (expanded-canonical), used only when expanded+fresh; collapsed-fresh falls back to below with label-only.
- **Entity roots** — same model, always expanded (Step 5 entity wiring, Step 6/10 entity fixtures/gate).
- **Notes dropped as line targets** — old note strip/fixtures removed (supersedes note).
- **Version-page non-leak** — `@comment_threads_by_anchor` nil off-candidate → helpers `[]`; Step 8 guards it with real data.
- **Removed superseded work** — `resolve_against` (Task 1), strip partial + 6 strip sites + `line_comment_threads_for` (Task 2) per the supersede list.
