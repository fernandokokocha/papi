# Candidate Commenting Stage 7: line-selection picker prototype (interaction-only) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In comment mode, let the user pick a rendered row in a response-output / entity-root JSON tree: hovering a row highlights it, clicking it highlights it persistently and captures the anchor — the row's **canonical expanded-tree index** plus the block's **whole-output snapshot** — shown in a prototype "pick chip" above the toolbar. No comment is created (that's Stage 8).

**Architecture:** Normalization is server-side: every pickable row is rendered with `data-line-index="<canonical expanded-tree index>"`. When the tree is rendered expanded that's just the row's own index; when collapsed, a new `Diff::LineIndexMap` aligns the collapsed row stream against the expanded row stream (entity references collapse an expanded subtree into one row) and each row carries its mapped index — so a pick made in a collapsed view is already canonical. The pickable block (the after-side output/root tree) carries `data-line-pick` container attributes (anchor dom_id, human label, whole-output snapshot). The existing `comment_mode_controller` gains the row-hover / row-click / chip behavior: a row click inside a pickable block wins over the whole-region compose click.

## Global Constraints

- **Interaction-only.** No `Comment` row is ever created; no form opens on a row pick; no new controller actions or routes. The pick lives in client-side state + the chip, and is discarded when comment mode deactivates.
- **The picker lives in comment mode** (Stage 5 toolbar, `data-controller="comment-mode"` on `app/views/candidates/show.html.erb:71`). This supersedes the earlier "＋ per line" idea in the comment-ui-conventions memory — per the user's Stage 7 instruction, picking a line is a comment-mode click, just finer-grained than the whole-region click.
- **Anchor model = Stage 6's** (docs/superpowers/plans/2026-07-06-candidate-commenting-stage6-line-anchored.md, NOT the original spec): `line` = 0-based row index in the block's **expanded** rendered tree (the `Diff::Lines` that `specs/_json` iterates, blanks included); snapshot = the **whole** current output text (e.g. `{total:number,items:[User]}`). At pick time the snapshot is by construction fresh.
- **Pickable = after-side / current trees only**: response output trees on the after side, and entity root trees for non-removed entities. Before-side columns, removed endpoints/entities/responses, and note text get **no** pick attributes. Blank alignment rows (`change == :blank`) are unpickable.
- **Version pages stay byte-clean**: every new helper returns an empty/nil result when `@candidate` is absent, so no `data-line-pick` / `data-line-index` ever renders outside candidate context.
- Keep the id contract: the `data-line-pick` container value is `CommentAnchor#dom_id` (part `output` / `root`, no line).
- Tailwind classes as complete literal strings; White & Sky palette; picker highlight uses sky tones. Custom CSS goes in `app/assets/tailwind/application.css` next to the existing comment-mode rules. Double quotes, 2-space indent, lean views (no ceremony comments).
- No TDD-first ordering: specs are written alongside/after the implementation; no "verify it fails" steps.
- Git: do NOT commit or branch. Stage with `git add -A`; a single Stage 7 commit is proposed to the user at the end. Pause at the Task 3 visual gate.

## Reference: verified row streams (ground truth, `bin/rails runner` 2026-07-06)

`User` root `{id:number,email:string,name:string}`; output `{total:number,items:[User]}`:

```
collapsed                          expanded                        map (collapsed idx → expanded idx)
[0] {                              [0] {                           0 → 0
[1] total: number                  [1] total: number               1 → 1
[2] items:                         [2] items:                      2 → 2
[3] [                              [3] [                           3 → 3
[4] User                           [4] {                           4 → 4  (first row of the subtree)
[5] ]                              [5] id: number                  5 → 9
[6] }                              [6] email: string               6 → 10
                                   [7] name: string
                                   [8] }
                                   [9] ]
                                   [10] }
```

Direct entity attribute `{owner:User,count:number}`: collapsed `owner: User` at [1] maps to expanded [1] (`owner:` label row, then `{`…`}` at [2]–[6]); `count: number` [2]→[7], `}` [3]→[8]. Map `[0, 1, 7, 8]`.

Diff with a removed attribute (`legacy` dropped): the collapsed after-side stream has a blank alignment row at [6] and `}` at [7]; the expanded after-side has its blank at [10] and `}` at [11]. Map `[0, 1, 2, 3, 4, 9, nil, 11]` — blanks map to `nil`, alignment survives.

Real rc4 case (`User` gained `avatar_url`, entity ref renders `type_changed`): collapsed 7 rows map `[0, 1, 2, 3, 4, 10, 11]` (expanded after-side has 12 rows).

Where the streams come from (mirrors the render paths exactly):
- changed/unchanged response: `Diff::FromValues.new(before.parsed_output, after.parsed_output).after` (collapsed) vs same with `.expand` on both (expanded) — this is what `DiffResponses::FromResponses` builds per code.
- wholesale added response (incl. new endpoints): `after.parsed_output.to_diff(:added)` vs `after.parsed_output.expand.to_diff(:added)`.
- entity roots: entities don't reference entities, so collapsed == expanded → identity, no map needed.

---

### Task 1: `Diff::LineIndexMap` — collapsed→expanded row-index normalization

A two-pointer aligner over the two after-side row streams. Invariant it relies on (holds by construction of the diff pipeline): the collapsed stream equals the expanded stream except (a) each entity reference is one row standing in for an expanded subtree, and (b) blank alignment rows may differ between the streams.

**Files:**
- Create: `app/models/diff/line_index_map.rb`
- Create: `spec/models/diff/line_index_map_spec.rb`

**Interfaces:**
- Consumes: `Diff::Lines` (`#lines`), `Diff::Line` (`#whole_line`, `#change`, `#is_opening`).
- Produces: `Diff::LineIndexMap.new(rendered_lines, expanded_lines).to_a` → `Array<Integer|nil>` where `result[rendered_index]` is the canonical expanded-tree index (`nil` for blank rows). Task 2's `response_line_index_map` helper wraps it.

- [ ] **Step 1: Implement the model** — create `app/models/diff/line_index_map.rb`:

```ruby
# Aligns a rendered (collapsed) after-side row stream against its expanded
# twin: rows match by text; a collapsed entity reference stands in for the
# expanded subtree that replaces it and maps to that subtree's first row.
class Diff::LineIndexMap
  CLOSERS = [ "}", "]" ].freeze

  def initialize(rendered_lines, expanded_lines)
    @rendered = rendered_lines.lines
    @expanded = expanded_lines.lines
  end

  # result[rendered_index] = canonical expanded-tree index; nil for blank
  # alignment rows (they are not pickable).
  def to_a
    e = 0
    @rendered.map do |row|
      next nil if row.change == :blank

      e += 1 while @expanded[e] && @expanded[e].change == :blank
      canonical = e
      e = row.whole_line == @expanded[e]&.whole_line ? e + 1 : skip_expansion(e)
      canonical
    end
  end

  private

  # Advance past the expanded subtree standing in for one collapsed entity
  # reference: an optional "name:" label row, then a bracketed block — or a
  # single row when the entity root is a primitive.
  def skip_expansion(e)
    e += 1 if @expanded[e].whole_line.end_with?(":")
    return e + 1 unless @expanded[e]&.is_opening

    depth = 1
    while depth.positive?
      e += 1
      depth += 1 if @expanded[e].is_opening
      depth -= 1 if CLOSERS.include?(@expanded[e].whole_line)
    end
    e + 1
  end
end
```

- [ ] **Step 2: Write the spec** — create `spec/models/diff/line_index_map_spec.rb`. Entities are built unsaved (`parsed_root` doesn't touch the version); the parser resolves entity names from the list it's given, exactly like `Response#parsed_output`:

```ruby
require "rails_helper"

describe Diff::LineIndexMap, type: :model do
  let(:version) { Version.new }
  let(:user_entity) { Entity.new(name: "User", root: "{id:number,email:string,name:string}", version: version) }
  let(:parser) { JSONSchemaParser.new([ user_entity ]) }

  def map_for(rendered, expanded)
    described_class.new(rendered, expanded).to_a
  end

  it "is the identity for a tree without entity references" do
    value = parser.parse_value("{total:number}")
    expect(map_for(value.to_diff(:added), value.expand.to_diff(:added))).to eq([ 0, 1, 2 ])
  end

  it "maps rows past a collapsed entity reference inside an array" do
    value = parser.parse_value("{total:number,items:[User]}")
    expect(map_for(value.to_diff(:added), value.expand.to_diff(:added))).to eq([ 0, 1, 2, 3, 4, 9, 10 ])
  end

  it "maps a labeled entity attribute to its expanded label row" do
    value = parser.parse_value("{owner:User,count:number}")
    expect(map_for(value.to_diff(:no_change), value.expand.to_diff(:no_change))).to eq([ 0, 1, 7, 8 ])
  end

  it "consumes a single expanded row for an entity with a primitive root" do
    tag_entity = Entity.new(name: "Tag", root: "string", version: version)
    tag_parser = JSONSchemaParser.new([ tag_entity ])
    value = tag_parser.parse_value("{tag:Tag,count:number}")
    expect(map_for(value.to_diff(:no_change), value.expand.to_diff(:no_change))).to eq([ 0, 1, 2, 3 ])
  end

  it "maps a bare entity root to the first row of its expansion" do
    value = parser.parse_value("User")
    expect(map_for(value.to_diff(:added), value.expand.to_diff(:added))).to eq([ 0 ])
  end

  it "maps blank alignment rows to nil and stays aligned past them" do
    before = parser.parse_value("{total:number,legacy:string,items:[User]}")
    after = parser.parse_value("{total:number,items:[User]}")
    rendered = Diff::FromValues.new(before, after).after
    expanded = Diff::FromValues.new(before.expand, after.expand).after
    expect(map_for(rendered, expanded)).to eq([ 0, 1, 2, 3, 4, 9, nil, 11 ])
  end

  it "maps a type_changed entity reference whose root gained a field" do
    old_user = Entity.new(name: "User", root: "{id:number,email:string,name:string}", version: version)
    new_user = Entity.new(name: "User", root: "{id:number,email:string,name:string,avatar_url:string}", version: version)
    before = JSONSchemaParser.new([ old_user ]).parse_value("{total:number,items:[User]}")
    after = JSONSchemaParser.new([ new_user ]).parse_value("{total:number,items:[User]}")
    rendered = Diff::FromValues.new(before, after).after
    expanded = Diff::FromValues.new(before.expand, after.expand).after
    expect(map_for(rendered, expanded)).to eq([ 0, 1, 2, 3, 4, 10, 11 ])
  end
end
```

- [ ] **Step 3: Run the spec**

Run: `bundle exec rspec spec/models/diff/line_index_map_spec.rb`
Expected: 7 examples, green. (The expected arrays are the verified ground truth from the Reference section — if one fails, debug the model, not the expectation.)

- [ ] **Step 4: Checkpoint** — report results. No commit.

---

### Task 2: Server-rendered pick metadata (`data-line-pick` containers + `data-line-index` rows)

Three helpers, a row attribute in `specs/_json`, a container attribute threaded through `response_cell` and the entity partials, wired at every after-side render site. Version pages and before-side columns render byte-identically.

**Files:**
- Modify: `app/helpers/comments_helper.rb` (append four methods)
- Modify: `app/views/specs/_json.html.erb`
- Modify: `app/views/endpoints/_response_cell.html.erb:44`
- Modify: `app/views/endpoints/_endpoint_diff.html.erb:50-53`
- Modify: `app/views/specs/_responses.html.erb:5-7`
- Modify: `app/views/versions/_endpoints_and_entities.html.erb:110-117` (entity branch)
- Modify: `app/views/versions/_entity_diff.html.erb:19`
- Modify: `app/views/versions/_entity_added.html.erb:8`
- Modify: `spec/requests/candidates_requests_spec.rb`, `spec/requests/endpoints_requests_spec.rb`, `spec/requests/versions_requests_spec.rb`

**Interfaces:**
- Consumes: `Diff::LineIndexMap` (Task 1), `CommentAnchor` (`#dom_id`, `#label`), `@candidate`, the `expanded` local already threaded through the endpoint partials.
- Produces:
  - `response_line_index_map(previous_endpoint, endpoint, code, expanded:)` → `nil` (not pickable: no candidate, or no current response) | `:identity` (expanded render) | `Array` (collapsed → expanded map).
  - `entity_line_index_map` → `nil` | `:identity`.
  - `response_line_pick_attr(endpoint, code, output, map)` / `entity_line_pick_attr(entity, map)` → the container attribute string (empty when `map` nil).
  - `line_index_attr(map, index, diff_line)` → `data-line-index="<canonical>"` per row (empty for nil map / blank rows).
  - `specs/_json` local `line_index_map:` (nil default); `response_cell` locals `line_index_map:` + `line_pick_attr:`.
  - Container attributes the Task 3 JS reads: `data-line-pick` (anchor dom_id), `data-line-pick-label`, `data-line-pick-snapshot`.

- [ ] **Step 1: Append the helpers** — in `app/helpers/comments_helper.rb`, after `partition_line_comments`:

```ruby
  # Canonical-index map for one response's rendered output tree: :identity when
  # rendered expanded, an Array (rendered row → expanded-tree row) when
  # collapsed, nil when not pickable (no candidate context, or the response has
  # no current side to pin to).
  def response_line_index_map(previous_endpoint, endpoint, code, expanded:)
    return nil unless @candidate
    after = endpoint.responses.find { |r| r.code == code }
    return nil unless after
    return :identity if expanded

    before = previous_endpoint&.responses&.find { |r| r.code == code }
    if before
      rendered = Diff::FromValues.new(before.parsed_output, after.parsed_output).after
      expanded_lines = Diff::FromValues.new(before.parsed_output.expand, after.parsed_output.expand).after
    else
      rendered = after.parsed_output.to_diff(:added)
      expanded_lines = after.parsed_output.expand.to_diff(:added)
    end
    Diff::LineIndexMap.new(rendered, expanded_lines).to_a
  end

  # Entity roots don't reference entities, so their trees render expanded as-is.
  def entity_line_index_map
    @candidate ? :identity : nil
  end

  def response_line_pick_attr(endpoint, code, output, map)
    return "".html_safe if map.nil?
    anchor = CommentAnchor.new(scope: "response", part: "output",
                               endpoint_path: endpoint.path, endpoint_http_verb: Endpoint.http_verbs[endpoint.http_verb],
                               response_code: code)
    line_pick_attributes(anchor, output)
  end

  def entity_line_pick_attr(entity, map)
    return "".html_safe if map.nil?
    line_pick_attributes(CommentAnchor.new(scope: "entity", part: "root", entity_name: entity.name), entity.root)
  end

  # data-line-index for one rendered row: its canonical expanded-tree index.
  # Blank alignment rows and non-pickable trees get nothing.
  def line_index_attr(map, index, diff_line)
    return "".html_safe if map.nil? || diff_line.change == :blank
    canonical = map == :identity ? index : map[index]
    return "".html_safe if canonical.nil?
    tag.attributes("data-line-index": canonical)
  end

  def line_pick_attributes(anchor, snapshot)
    tag.attributes("data-line-pick": anchor.dom_id, "data-line-pick-label": anchor.label, "data-line-pick-snapshot": snapshot)
  end
```

- [ ] **Step 2: Row attribute in `specs/_json`** — replace `app/views/specs/_json.html.erb` line 5–6 so each row emits its index:

```erb
  <% line_index_map = local_assigns[:line_index_map] %>
  <% diff.each.with_index do |diff_line, i| %>
    <div class="line <%= diff_line.change %>" <%= line_index_attr(line_index_map, i, diff_line) %>><%= render_type(diff_line) %></div>
```

(Keep the `comments_by_line` interleave and the rest of the file unchanged. Callers that don't pass `line_index_map` render with no pick attributes — same pattern as the empty `comment_region_attr`, which also leaves a stray space inside the tag.)

- [ ] **Step 3: Container + forward in `response_cell`** — in `app/views/endpoints/_response_cell.html.erb`, change line 44 to:

```erb
      <div <%= local_assigns[:line_pick_attr] %> class="font-mono text-xs text-gray-800 mt-1"><%= render "specs/json", diff: body, comments_by_line: local_assigns[:comments_by_line] || {}, line_index_map: local_assigns[:line_index_map] %></div>
```

- [ ] **Step 4: Wire `_endpoint_diff`** — in `app/views/endpoints/_endpoint_diff.html.erb`, after line 51 (`resp_line_comments = ...`) add the map, and extend only the **after** cell render (line 53):

```erb
      <% resp_map = response_line_index_map(previous_endpoint, endpoint, line.code, expanded: expanded) %>
      <%= render "endpoints/response_cell", line: line, side: :before, region_attr: comment_region_attr(resp_anchor) %>
      <%= render "endpoints/response_cell", line: line, side: :after, curl_verb: endpoint.verb, curl_path: endpoint.path, region_attr: comment_region_attr(resp_anchor), comments_by_line: resp_line_comments[:inline], line_index_map: resp_map, line_pick_attr: response_line_pick_attr(endpoint, line.code, resp_record&.output, resp_map) %>
```

(Removed responses have no after side → `response_line_index_map` returns nil → the after cell renders the empty else-branch anyway.)

- [ ] **Step 5: Wire `specs/_responses`** (new/removed endpoint cards) — in `app/views/specs/_responses.html.erb`, after line 6 (`resp_line_comments = ...`) add the side-gated map and extend the cell render (line 7):

```erb
    <% resp_map = side == :after ? response_line_index_map(nil, endpoint, line.code, expanded: expanded) : nil %>
    <%= render "endpoints/response_cell", line: line, side: side, curl_verb: local_assigns[:curl_verb], curl_path: local_assigns[:curl_path], region_attr: comment_region_attr(resp_anchor), comments_by_line: resp_line_comments[:inline], line_index_map: resp_map, line_pick_attr: response_line_pick_attr(endpoint, line.code, resp_record&.output, resp_map) %>
```

(`_endpoint_new` passes `side: :after` → pickable; `_endpoint_removed` passes `side: :before` → `resp_map` nil → no attributes. No changes needed in those two partials.)

- [ ] **Step 6: Wire the entity trees** — in `app/views/versions/_endpoints_and_entities.html.erb` entity branch (lines 110–117), compute the map once and pass pick locals into the non-removed renders:

```erb
            <% entity_line_comments = partition_line_comments(entity_root_comments(entity), entity.root, expanded: entity.annotation != "removed") %>
            <% entity_map = entity_line_index_map %>
            <% if entity.annotation == "unchanged" || entity.annotation == "changed" %>
              <% diff = Diff::FromValues.new(entity.previous.parsed_root, entity.parsed_root) %>
              <%= render "versions/entity_diff", entity: entity, previous_entity: entity.previous, diff: diff, comments_by_line: entity_line_comments[:inline], line_index_map: entity_map, line_pick_attr: entity_line_pick_attr(entity, entity_map) %>
            <% elsif entity.annotation == "added" %>
              <% diff = entity.parsed_root.to_diff(:no_change) %>
              <%= render "versions/entity_added", entity: entity, diff: diff, comments_by_line: entity_line_comments[:inline], line_index_map: entity_map, line_pick_attr: entity_line_pick_attr(entity, entity_map) %>
            <% elsif entity.annotation == "removed" %>
              <% diff = entity.parsed_root.to_diff(:no_change) %>
              <%= render "versions/entity_removed", entity: entity, diff: diff %>
            <% end %>
```

In `app/views/versions/_entity_diff.html.erb` line 19 (the **after** side only):

```erb
      <div <%= local_assigns[:line_pick_attr] %> class="pl-2 py-2 bg-white border-b border-gray-200"><%= render "specs/json", diff: diff.after, comments_by_line: local_assigns[:comments_by_line] || {}, line_index_map: local_assigns[:line_index_map] %></div>
```

In `app/views/versions/_entity_added.html.erb` line 8:

```erb
      <div <%= local_assigns[:line_pick_attr] %> class="pl-2 py-2 bg-emerald-50 border-b border-emerald-200"><%= render "specs/json", diff: diff, comments_by_line: local_assigns[:comments_by_line] || {}, line_index_map: local_assigns[:line_index_map] %></div>
```

(`_entity_removed` untouched — removed entities aren't pickable.)

- [ ] **Step 7: Candidate request spec** — in `spec/requests/candidates_requests_spec.rb`, inside `describe "#show inline comment threads"` (or a sibling `describe "#show line picker metadata"`), add — same POST shape as the existing collapsed line-threads example (User root `{id:number,email:string,name:string}`, output `{total:number,items:[User]}`; the page renders collapsed by default):

```ruby
    it "marks pickable trees with normalized expanded-tree indices on the collapsed page" do
      sign_in(user)
      post project_candidates_path(project.name), params: {
        candidate: { project_id: project.id, name: "rc1" },
        version: {
          name: "v1",
          order: 1,
          endpoints_attributes: [
            { path: "/users",
              http_verb: "verb_get",
              responses: { "200" => { note: "List users", output: "{total:number,items:[User]}" } } }
          ],
          entities_attributes: [
            { name: "User", root: "{id:number,email:string,name:string}" }
          ]
        }
      }
      candidate = Candidate.find_by!(name: "rc1")

      get project_candidate_path(project.name, candidate.name)

      expect(response.body).to include('data-line-pick="comment_anchor_')
      expect(response.body).to include('data-line-pick-label="GET /users → 200 → output"')
      expect(response.body).to include('data-line-pick-label="User → root"')
      expect(response.body).to include('data-line-pick-snapshot="{total:number,items:[User]}"')
      expect(response.body).to include('data-line-index="9"')   # the "]" row, normalized past the collapsed User subtree
      expect(response.body).to include('data-line-index="10"')  # the closing "}" of the output tree
    end
```

- [ ] **Step 8: Endpoint re-render spec** — in `spec/requests/endpoints_requests_spec.rb` `describe "#show"`, add (the existing `valid_params` endpoint `/` has output `User`, root `{ name: string }`; candidate re-renders default to expanded):

```ruby
    it "emits pick metadata only when re-rendering for a candidate page" do
      sign_in(user)
      post project_candidates_path(project.name), params: valid_params
      candidate = Candidate.find_by!(name: "rc1")
      endpoint = Endpoint.last

      get project_endpoint_path(project.name, endpoint.id, candidate: candidate.name)
      expect(response.body).to include('data-line-pick-label="GET / → 200 → output"')
      expect(response.body).to include('data-line-index="2"')   # identity indices on the expanded tree

      get project_endpoint_path(project.name, endpoint.id, candidate: candidate.name, expanded: "false")
      expect(response.body).to include('data-line-index="0"')   # the collapsed "User" row, canonical index 0
      expect(response.body).not_to include('data-line-index="1"')

      get project_endpoint_path(project.name, endpoint.id)
      expect(response.body).not_to include("data-line-pick")
      expect(response.body).not_to include("data-line-index")
    end
```

- [ ] **Step 9: Version-page non-leak** — in `spec/requests/versions_requests_spec.rb`, in the existing example that asserts `not_to include("Outdated")` / `not_to include("· line 0")` (around lines 62–63), add:

```ruby
      expect(response.body).not_to include("data-line-pick")
      expect(response.body).not_to include("data-line-index")
```

- [ ] **Step 10: Run the affected specs, then the suite**

Run: `bundle exec rspec spec/requests/candidates_requests_spec.rb spec/requests/endpoints_requests_spec.rb spec/requests/versions_requests_spec.rb`
Expected: green.
Run: `bundle exec rspec && bin/rubocop`
Expected: full suite green, no offenses.

- [ ] **Step 11: Checkpoint** — report results. No commit; the interaction lands in Task 3.

---

### Task 3: The picker interaction (comment-mode rows + pick chip) — ends at the visual gate

Row hover-highlight and click-to-pick inside comment mode, with the captured anchor shown in a chip above the toolbar. A row click wins over the whole-region compose; everything else about comment mode is unchanged.

**Files:**
- Modify: `app/javascript/controllers/comment_mode_controller.js`
- Modify: `app/views/comments/_toolbar.html.erb`
- Modify: `app/assets/tailwind/application.css`

**Interfaces:**
- Consumes: `data-line-pick` / `data-line-pick-label` / `data-line-pick-snapshot` containers and `data-line-index` rows (Task 2); existing comment-mode targets/exemptions.
- Produces: comment-mode targets `chip`, `chipLabel`, `chipSnapshot`; row classes `.line-pick-highlight` (hover) and `.line-picked` (picked). Stage 8 will replace the chip with the compose form fed by the same captured values.

- [ ] **Step 1: Extend the controller** — replace `app/javascript/controllers/comment_mode_controller.js` with:

```js
import { Controller } from "@hotwired/stimulus"

// Figma-style comment mode for the candidate page. Toggled from the toolbar
// (or the "C" key). While on: the cursor becomes a 💬 pin, hovering a
// [data-comment-region] target outlines it (.anchor-highlight), and clicking
// opens that target's anchored compose form (#<dom_id>_form). Rows inside a
// [data-line-pick] tree are finer-grained targets: hovering highlights the
// row, clicking picks it — capturing the canonical expanded-tree index and
// the block's whole-output snapshot into the pick chip (no comment yet).
// Stays on until Esc or toggled off. Threads / open compose / toolbar stay
// interactive; other in-target controls (Copy cURL, Expand) are suppressed.
export default class extends Controller {
  static targets = ["button", "pin", "chip", "chipLabel", "chipSnapshot"]

  connect() {
    this.onMove = this.onMove.bind(this)
    this.onClick = this.onClick.bind(this)
    this.onKey = this.onKey.bind(this)
    document.addEventListener("keydown", this.onKey)
  }

  disconnect() {
    this.deactivate()
    document.removeEventListener("keydown", this.onKey)
  }

  toggle() { this.active ? this.deactivate() : this.activate() }

  activate() {
    this.active = true
    document.body.classList.add("commenting")
    this.buttonTarget.setAttribute("aria-pressed", "true")
    document.addEventListener("mousemove", this.onMove)
    document.addEventListener("click", this.onClick, true)
  }

  deactivate() {
    if (!this.active) return
    this.active = false
    document.body.classList.remove("commenting")
    this.buttonTarget.setAttribute("aria-pressed", "false")
    this.clearHighlight()
    this.hoverRow(null)
    this.clearPick()
    document.removeEventListener("mousemove", this.onMove)
    document.removeEventListener("click", this.onClick, true)
  }

  onKey(e) {
    if (e.key === "Escape") {
      const open = e.target.closest && e.target.closest("[data-comment-form]")
      if (open) { open.hidden = true; this.buttonTarget.focus(); return }
      if (this.active) this.deactivate()
      return
    }
    const el = document.activeElement
    const typing = el && /^(TEXTAREA|INPUT|SELECT)$/.test(el.tagName)
    if ((e.key === "c" || e.key === "C") && !typing && !e.metaKey && !e.ctrlKey && !e.altKey) {
      e.preventDefault()
      this.toggle()
    }
  }

  onMove(e) {
    if (e.target.closest(".anchor-strip") || e.target.closest("[data-comment-toolbar]") || e.target.closest("[data-comment-exempt]")) {
      this.pinTarget.style.opacity = "0"
      this.clearHighlight()
      this.hoverRow(null)
      return
    }
    this.pinTarget.style.opacity = "1"
    this.pinTarget.style.left = e.clientX + "px"
    this.pinTarget.style.top = e.clientY + "px"
    const row = this.pickableRow(e.target)
    this.hoverRow(row)
    this.highlight(row ? null : e.target.closest("[data-comment-region]"))
  }

  onClick(e) {
    if (e.target.closest("[data-comment-close]")) {
      const f = e.target.closest("[data-comment-form]")
      if (f) f.hidden = true
      return
    }
    if (e.target.closest("[data-comment-toolbar]") || e.target.closest(".anchor-strip") || e.target.closest("[data-comment-exempt]")) return
    const row = this.pickableRow(e.target)
    if (row) {
      e.preventDefault()
      e.stopPropagation()
      this.pick(row)
      return
    }
    const t = e.target.closest("[data-comment-region]")
    if (!t) return
    e.preventDefault()
    e.stopPropagation()
    this.openCompose(t.getAttribute("data-comment-region"))
  }

  pickableRow(target) {
    const row = target.closest && target.closest("[data-line-index]")
    return row && row.closest("[data-line-pick]") ? row : null
  }

  pick(row) {
    this.clearPick()
    this.picked = row
    row.classList.add("line-picked")
    const block = row.closest("[data-line-pick]")
    this.chipLabelTarget.textContent = block.getAttribute("data-line-pick-label") + " · line " + row.getAttribute("data-line-index")
    this.chipSnapshotTarget.textContent = block.getAttribute("data-line-pick-snapshot")
    this.chipTarget.hidden = false
  }

  clearPick() {
    if (this.picked) this.picked.classList.remove("line-picked")
    this.picked = null
    if (this.hasChipTarget) this.chipTarget.hidden = true
  }

  hoverRow(row) {
    if (this.hovered === row) return
    if (this.hovered) this.hovered.classList.remove("line-pick-highlight")
    this.hovered = row
    if (row) row.classList.add("line-pick-highlight")
  }

  openCompose(domId) {
    this.clearHighlight()
    this.clearPick()
    const form = document.getElementById(domId + "_form")
    if (!form) return
    // Only one anchored composer open at a time — close any other.
    document.querySelectorAll("[data-comment-form]:not([hidden])").forEach(f => { if (f !== form) f.hidden = true })
    form.hidden = false
    const ta = form.querySelector("textarea")
    if (ta) ta.focus()
  }

  highlight(el) {
    if (this.hl === el) return
    this.clearHighlight()
    this.hl = el
    if (el) el.classList.add("anchor-highlight")
  }

  clearHighlight() {
    if (this.hl) { this.hl.classList.remove("anchor-highlight"); this.hl = null }
  }
}
```

- [ ] **Step 2: Add the pick chip to the toolbar partial** — in `app/views/comments/_toolbar.html.erb`, append after the existing pin `<span>`:

```erb
<div data-comment-toolbar data-comment-mode-target="chip" hidden class="fixed bottom-20 left-1/2 -translate-x-1/2 z-50 max-w-xl bg-white border border-gray-200 rounded-lg shadow-lg px-3 py-2 flex flex-col gap-1">
  <span class="text-xs font-semibold text-gray-700"><span aria-hidden="true">📌</span> <span data-comment-mode-target="chipLabel" class="font-mono"></span></span>
  <span data-comment-mode-target="chipSnapshot" class="bg-gray-100 text-gray-800 font-mono text-xs px-2 py-1 rounded border border-gray-200 whitespace-pre-wrap break-all"></span>
</div>
```

(`data-comment-toolbar` on the chip reuses the existing exemptions — hovering/clicking it neither pins nor picks.)

- [ ] **Step 3: Picker CSS** — in `app/assets/tailwind/application.css`, append after the existing comment-mode rules (after the `[data-action*="endpoint#"]` line):

```css
/* Line picker (comment mode): hovered and picked rows in a pickable tree */
.line-pick-highlight { background-color: var(--color-sky-100); }
.line-picked {
  background-color: var(--color-sky-100);
  outline: 2px solid var(--color-sky-500);
  outline-offset: -2px;
  border-radius: 0.25rem;
}
```

- [ ] **Step 4: Build assets and sanity-check**

Run: `bin/rails tailwindcss:build && bin/vite build`
Expected: both succeed.
Run: `bundle exec rspec && bin/rubocop`
Expected: green, no offenses.

- [ ] **Step 5: VISUAL CHECKPOINT (user gate)** — on rc4's candidate page (`bin/dev` running):
  - Toggle comment mode (`C` or the pill). Hover the `GET /users` 200 output tree: individual rows highlight sky; hovering the note/header area still outlines the whole response region.
  - **Collapsed pick:** click the `User` row in the collapsed tree → row gets the persistent sky outline; the chip shows `GET /users → 200 → output · line 4` (the canonical expanded index) and the whole-output snapshot `{total:number,items:[User]}`-style text.
  - **Normalization proof:** click the closing `]` / `}` rows in the collapsed tree → chip shows the expanded indices (they jump past the hidden subtree, e.g. `line 10` / `line 11` on rc4).
  - **Expand** the endpoint and click the same logical row (e.g. a field inside `User`) → chip shows its own index; picking replaces the previous pick (one pick at a time).
  - Entity `User` tree rows pick with identity indices; the removed entity (if any) and all before-side columns are not pickable.
  - Blank alignment rows don't react. Clicking a row does NOT open a compose form; clicking the response header/note still does (and clears the pick). `Esc` / toggling off clears pick + chip. Version page `v4`: no picker, byte-clean.
  - Note for the gate: the pick highlight does not survive an Expand/Collapse re-render (the card is re-fetched); the chip keeps the captured anchor. Acceptable for the prototype — Stage 8's compose form will own that state.
  - Tune highlight tones, chip placement/wording per feedback.

---

### Task 4: Verification + proposed commit

- [ ] **Step 1: Full verification**

Run: `bundle exec rspec && bin/rubocop && bundle exec brakeman -q`
Expected: suite green, no offenses, no new warnings.

- [ ] **Step 2: Stage and propose** — `git add -A`, show `git status` + a short diffstat, and propose the commit message:

```
Add candidate commenting Stage 7: line-selection picker prototype
```

Commit **only on the user's explicit go-ahead** (straight to main, no Co-Authored-By, per workflow).

---

## Self-review notes (traceability)

- **Pick a rendered row in comment mode** (user instruction; supersedes the memory's "＋ per line" note) — Task 3 row hover/click inside the existing comment-mode listeners; region compose still reachable off-row.
- **Anchor = expanded-tree index + whole-output snapshot** (Stage 6 model) — `data-line-index` (canonical) + `data-line-pick-snapshot` (current whole output, fresh at pick time); chip renders `label · line N` matching `CommentAnchor#label`'s format.
- **Collapsed pick normalizes to canonical expanded index** — `Diff::LineIndexMap` (Task 1, ground-truth-verified maps) rendered server-side per row, so the client never computes indices.
- **Creates no comment** — no controller/model/route changes beyond the render metadata; pick state is client-side and discarded on deactivate.
- **Version pages / before sides / removed targets byte-clean** — every helper gates on `@candidate` and map presence; endpoint re-render + version non-leak specs (Task 2 Steps 8–9) guard it.
- **Id contract** — `data-line-pick` value is `CommentAnchor#dom_id` (scope response/part output, scope entity/part root).
- **Blank rows unpickable** — `line_index_attr` skips `change == :blank`; map yields `nil` for them.
