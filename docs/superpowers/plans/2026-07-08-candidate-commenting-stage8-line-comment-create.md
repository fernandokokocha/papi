# Candidate Commenting Stage 8: line pick → comment creation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In comment mode, picking a row in a pickable output/root tree opens a real compose form for that block's line anchor (part `output`/`root`), pre-fed with the captured canonical expanded-tree `line`; submitting creates the comment with `anchor_snapshot` resolved **server-side** to the block's whole current output, and the new thread streams into place per the Stage 6 rules — inline under its row when the block was expanded (fresh by construction at create), below the block with a **Collapsed** badge otherwise. The Stage 7 prototype chip is removed.

**Architecture:** Each pickable block gains a hidden line compose form `#<line-anchor dom_id>_form` (the same dom_id the block's `data-line-pick` carries), rendered in the right-side strip next to the existing below-block threads. The form is the standard `comments/_form` with two extra hidden fields: `comment[line]` (filled by JS at pick time) and a top-level `expanded` flag (stamped at card render, so the create response knows the client's view state). `comment_mode_controller#pick` swaps the chip for opening that form. On create, the controller permits `:line` and sets `anchor_snapshot = anchor.current_output(candidate.latest_version)` — the client can neither omit nor forge it. The turbo-stream response places the thread with `turbo_stream.after_all` (CSS `targets` selector onto the picked row — turbo-rails 2.0.16 supports it) when expanded, or appends into a new always-present id'd container inside `comments/_line_threads` when collapsed.

> **Shipped deviations (visual-gate rulings, supersede the code below):** (1) the line compose form opens *where the created comment will land* — JS moves `#<dom_id>_form` inline under the picked row when the block is expanded, back to a home slot `#<dom_id>_form_home` (new wrapper in `_line_threads`) when collapsed; `[data-comment-form]` joined the comment-mode exemption checks. (2) The line branch of `create.turbo_stream.erb` therefore emits `remove "#<dom_id>_form"` + `update "#<dom_id>_form_home"` (fresh compose) instead of Task 3's replace-in-place. (3) `data-line-pick-snapshot` was dropped post-review as dead data — the chip was its only consumer and the server resolves snapshots.

## Global Constraints

- **Anchor model = Stage 6's** (docs/superpowers/plans/2026-07-06-candidate-commenting-stage6-line-anchored.md): `line` = 0-based row index in the block's **expanded** rendered tree; snapshot = the **whole** current output text; Outdated = whole-block compare. At create time the snapshot is fresh by construction, so placement depends only on the block's expanded state.
- **Snapshot is server-resolved.** `anchor_snapshot` is never mass-assigned from params (it stays out of the permit lists); the controller resolves it from the addressed block at pin time. A line comment whose target can't be resolved is invalid (snapshot presence validation) → "Comment could not be posted."
- **The pick contract is Stage 7's** (docs/superpowers/plans/2026-07-06-candidate-commenting-stage7-line-picker.md): `data-line-pick` = line-anchor `CommentAnchor#dom_id` (part `output`/`root`, no line), rows carry canonical `data-line-index`, blank rows and non-pickable trees carry nothing. Stage 8 only consumes these attributes; it does not change how they render.
- **Id contract** (comment-ui-conventions memory): everything keys off `CommentAnchor#dom_id`. New DOM: the line compose is `#<line-anchor dom_id>_form`; the below-block append target is `#<line-anchor dom_id>_line_threads`. New comment surfaces carry `anchor-strip`.
- **Version pages stay byte-clean**: the line compose renders only when the block is pickable (`composable:` gated by the Stage 7 maps, which are nil without `@candidate`); the id'd container renders only when the strip renders at all.
- Pick UX: the picked row keeps its `.line-picked` outline while its compose form is open; it clears on cancel/Esc/another pick/region compose/successful create. Comment mode stays on after create (pin several). The chip is removed; its label info moves into the form as a small `📌 <label> · line N` header.
- Accepted (out of scope): no server-side bounds check on `line` (a forged index would need the base-diff row count to validate; a forged-but-fresh comment just renders below/never inline). A thread streamed inline lands directly after its row, so it sits above older same-line threads until the next full render sorts by `created_at`. Cancel buttons only respond while comment mode is on (pre-existing).
- Tailwind classes as complete literal strings; White & Sky palette; double quotes; 2-space indent; lean views. No new CSS needed (`.line-picked` etc. exist).
- No TDD-first ordering: specs alongside/after impl; no "verify it fails" steps.
- Git: do NOT commit or branch. Stage with `git add -A`; a single Stage 8 commit is proposed at the end. Pause at the Task 2 and Task 3 visual gates.

---

### Task 1: Server write path — permit `:line`, resolve the snapshot, validate it

**Files:**
- Modify: `app/models/comment_anchor.rb`
- Modify: `app/controllers/comments_controller.rb`
- Modify: `app/models/comment.rb`
- Modify: `spec/models/comment_anchor_spec.rb`
- Modify: `spec/models/comment_spec.rb`
- Modify: `spec/requests/comments_requests_spec.rb`

**Interfaces:**
- Consumes: `Candidate#latest_version`, `Endpoint` enum `http_verb` (integer values), `Response#code`/`#output`, `Entity#name`/`#root`.
- Produces:
  - `CommentAnchor.from_params` now parses `line:` (`Integer` or nil).
  - `CommentAnchor#without_line` → a new anchor with the same scope/part/identity and `line: nil` (its `dom_id` is the pick-region id). Task 3's turbo stream uses it.
  - `CommentAnchor#current_output(version)` → `String` (the addressed block's whole current output: response `output` for part `"output"`, entity `root` for part `"root"`) or nil when the target doesn't exist.
  - `Comment` validates `anchor_snapshot` presence when `line` is set.
  - `POST /projects/:project_name/candidates/:candidate_name/comments` accepts `comment[line]` and stores the server-resolved snapshot.

- [ ] **Step 1: Extend `CommentAnchor`** — in `app/models/comment_anchor.rb`, add `line:` to `from_params` and two methods after `to_columns`:

```ruby
  def self.from_params(params)
    new(
      scope: (params[:scope] || params["scope"]).presence || "candidate",
      part: (params[:part] || params["part"]).presence || "whole",
      line: (params[:line] || params["line"]).presence&.to_i,
      endpoint_path: (params[:endpoint_path] || params["endpoint_path"]).presence,
      endpoint_http_verb: (params[:endpoint_http_verb] || params["endpoint_http_verb"]).presence&.to_i,
      entity_name: (params[:entity_name] || params["entity_name"]).presence,
      response_code: (params[:response_code] || params["response_code"]).presence
    )
  end
```

```ruby
  # The same anchor without the line — the pick region every line comment's
  # DOM (compose form, below-block container) is keyed off.
  def without_line
    self.class.new(scope: scope, part: part,
                   endpoint_path: endpoint_path, endpoint_http_verb: endpoint_http_verb,
                   entity_name: entity_name, response_code: response_code)
  end

  # The whole current output of the addressed block in the given version;
  # nil when the block doesn't exist there.
  def current_output(version)
    case part
    when "output"
      version.endpoints.find_by(path: endpoint_path, http_verb: endpoint_http_verb)
        &.responses&.find_by(code: response_code)&.output
    when "root"
      version.entities.find_by(name: entity_name)&.root
    end
  end
```

- [ ] **Step 2: Controller** — in `app/controllers/comments_controller.rb`, replace the anchor assignment line and the permit:

```ruby
    if @comment.parent_id.blank?
      anchor = CommentAnchor.from_params(anchor_params)
      @comment.assign_attributes(anchor.to_columns)
      @comment.anchor_snapshot = anchor.current_output(@candidate.latest_version) if anchor.line
    end
```

```ruby
  def anchor_params
    params.require(:comment).permit(:scope, :part, :line, :endpoint_path, :endpoint_http_verb, :entity_name, :response_code)
  end
```

(Keep `authorize @comment` after the assignment, as now. `anchor_snapshot` stays out of both permit lists.)

- [ ] **Step 3: Model validation** — in `app/models/comment.rb`, after the existing `validates :body`:

```ruby
  validates :anchor_snapshot, presence: true, if: :line
```

(Replies inherit `anchor_snapshot` from the parent via `inherit_parent_anchor` before validation, so they pass. All existing fixtures/spec seeds set a snapshot alongside `line`.)

- [ ] **Step 4: Anchor model specs** — in `spec/models/comment_anchor_spec.rb`, add to `describe ".from_params"`:

```ruby
    it "parses line to an integer and leaves it nil when blank" do
      expect(described_class.from_params({ "scope" => "response", "part" => "output", "line" => "4" }).line).to eq(4)
      expect(described_class.from_params({ "scope" => "response", "part" => "output", "line" => "" }).line).to be_nil
    end
```

and two new describes (top-level, alongside `#label`):

```ruby
  describe "#without_line" do
    it "keeps the identity and drops the line" do
      with_line = anchor(scope: "response", part: "output", endpoint_path: "/users",
                         endpoint_http_verb: 0, response_code: "200", line: 4)
      expect(with_line.without_line.key).to eq([ "response", "/users", 0, nil, "200", "output", nil ])
    end
  end

  describe "#current_output" do
    let(:version) { FactoryBot.create :version }
    let(:endpoint) { FactoryBot.create :endpoint, version: version, path: "/users", http_verb: "verb_get" }

    before do
      FactoryBot.create :response, endpoint: endpoint, code: "200", output: "{total:number,items:[User]}"
      FactoryBot.create :entity, version: version, name: "User", root: "{id:number}"
    end

    it "returns the response output for a response/output anchor" do
      a = anchor(scope: "response", part: "output", endpoint_path: "/users", endpoint_http_verb: 0, response_code: "200")
      expect(a.current_output(version)).to eq("{total:number,items:[User]}")
    end

    it "returns the entity root for an entity/root anchor" do
      a = anchor(scope: "entity", part: "root", entity_name: "User")
      expect(a.current_output(version)).to eq("{id:number}")
    end

    it "is nil when the target does not exist in the version" do
      a = anchor(scope: "response", part: "output", endpoint_path: "/users", endpoint_http_verb: 0, response_code: "404")
      expect(a.current_output(version)).to be_nil
    end
  end
```

(`anchor(**attrs)` is the spec's existing builder helper.)

- [ ] **Step 5: Comment model spec** — in `spec/models/comment_spec.rb`, next to the anchor-validation examples:

```ruby
    it "requires a snapshot on a line comment" do
      comment = FactoryBot.build :comment, :response_scope, part: "output", line: 4
      expect(comment).not_to be_valid
      expect(comment.errors[:anchor_snapshot]).to be_present
      comment.anchor_snapshot = "{total:number}"
      expect(comment).to be_valid
    end
```

- [ ] **Step 6: Request specs for the write path** — in `spec/requests/comments_requests_spec.rb`, add inside `describe "#create"` a nested group with its own data:

```ruby
    describe "line-anchored roots" do
      let!(:version) { FactoryBot.create :version, candidate: candidate, project: project, order: 1 }
      let!(:endpoint) { FactoryBot.create :endpoint, version: version, path: "/users", http_verb: "verb_get" }
      let!(:response_200) { FactoryBot.create :response, endpoint: endpoint, code: "200", output: "{total:number,items:[User]}" }
      let!(:entity) { FactoryBot.create :entity, version: version, name: "User", root: "{id:number,email:string}" }
      let(:line_params) do
        { comment: { body: "Pinned to the User row", scope: "response", part: "output",
                     endpoint_path: "/users", endpoint_http_verb: "0", response_code: "200", line: "4" } }
      end

      it "creates a line comment with the snapshot resolved server-side" do
        sign_in(user)
        post project_candidate_comments_path(project.name, candidate.name), params: line_params

        comment = Comment.last
        expect(comment.line).to eq(4)
        expect(comment.anchor_snapshot).to eq("{total:number,items:[User]}")
      end

      it "ignores a client-supplied anchor_snapshot" do
        sign_in(user)
        forged = line_params.deep_merge(comment: { anchor_snapshot: "forged" })
        post project_candidate_comments_path(project.name, candidate.name), params: forged

        expect(Comment.last.anchor_snapshot).to eq("{total:number,items:[User]}")
      end

      it "resolves an entity root-line comment against the entity root" do
        sign_in(user)
        post project_candidate_comments_path(project.name, candidate.name),
             params: { comment: { body: "Pinned to email", scope: "entity", part: "root", entity_name: "User", line: "2" } }

        expect(Comment.last.anchor_snapshot).to eq("{id:number,email:string}")
      end

      it "rejects a line comment whose target does not exist" do
        sign_in(user)
        bad = { comment: line_params[:comment].merge(response_code: "404") }
        expect {
          post project_candidate_comments_path(project.name, candidate.name), params: bad
        }.not_to change(Comment, :count)
        expect(flash[:alert]).to eq("Comment could not be posted.")
      end
    end
```

- [ ] **Step 7: Run the touched specs**

Run: `bundle exec rspec spec/models/comment_anchor_spec.rb spec/models/comment_spec.rb spec/requests/comments_requests_spec.rb`
Expected: green.

- [ ] **Step 8: Checkpoint** — report results. No commit; the UI lands in Task 2.

---

### Task 2: The line compose form — render it per pickable block, open it on pick, drop the chip

**Files:**
- Modify: `app/helpers/comments_helper.rb` (two anchor builders, reused by the pick attrs)
- Modify: `app/views/comments/_form.html.erb`
- Modify: `app/views/comments/_compose.html.erb`
- Modify: `app/views/comments/_line_threads.html.erb`
- Modify: `app/views/endpoints/_endpoint_diff.html.erb:59`
- Modify: `app/views/specs/_responses.html.erb:13`
- Modify: `app/views/versions/_endpoints_and_entities.html.erb:126`
- Modify: `app/javascript/controllers/comment_mode_controller.js`
- Modify: `app/views/comments/_toolbar.html.erb`
- Modify: `spec/requests/candidates_requests_spec.rb`, `spec/requests/versions_requests_spec.rb`

**Interfaces:**
- Consumes: Stage 7's `data-line-pick` / `data-line-pick-label` containers and `data-line-index` rows; `resp_map` / `entity_map` locals already computed at the call sites; `partition_line_comments` output.
- Produces:
  - `response_output_anchor(endpoint, code)` / `entity_root_anchor(entity)` → the line-region `CommentAnchor` (part `output`/`root`, no line).
  - `comments/_line_threads` locals: `anchor:`, `collapsed:`, `outdated:`, `composable:`, `expanded:`, `wrapper_class:`; renders `#<anchor.dom_id>_line_threads` (append target) and, when composable, the line compose.
  - `comments/_compose` / `comments/_form` pass-through locals `line_pin:` + `expanded:`; a line-pin form contains `input[name="comment[line]"]`, `input[name="expanded"]`, and a `[data-pick-label]` header the JS fills.
  - JS: `pick(row)` opens the block's line form; `pickedForm` state; chip targets/markup gone.

- [ ] **Step 1: Anchor builders in the helper** — in `app/helpers/comments_helper.rb`, add above `response_line_pick_attr` and slim both pick attrs to reuse them:

```ruby
  # The line-region anchor (part output/root, no line) a block's picks,
  # compose form, and below-block container are keyed off.
  def response_output_anchor(endpoint, code)
    CommentAnchor.new(scope: "response", part: "output",
                      endpoint_path: endpoint.path, endpoint_http_verb: Endpoint.http_verbs[endpoint.http_verb],
                      response_code: code)
  end

  def entity_root_anchor(entity)
    CommentAnchor.new(scope: "entity", part: "root", entity_name: entity.name)
  end

  def response_line_pick_attr(endpoint, code, output, map)
    return "".html_safe if map.nil?
    line_pick_attributes(response_output_anchor(endpoint, code), output)
  end

  def entity_line_pick_attr(entity, map)
    return "".html_safe if map.nil?
    line_pick_attributes(entity_root_anchor(entity), entity.root)
  end
```

- [ ] **Step 2: `_form` gains the line-pin fields** — in `app/views/comments/_form.html.erb`, inside the root (`else`) branch of the parent check, after the `response_code` hidden field add:

```erb
    <% if local_assigns[:line_pin] %>
      <div data-pick-label class="font-mono text-xs text-gray-500 mb-2"></div>
      <%= form.hidden_field :line %>
      <%= hidden_field_tag :expanded, local_assigns[:expanded] %>
    <% end %>
```

- [ ] **Step 3: `_compose` passes the locals through** — replace `app/views/comments/_compose.html.erb` line 2:

```erb
  <%= render "comments/form", candidate: @candidate, parent: nil, anchor: anchor, line_pin: local_assigns[:line_pin], expanded: local_assigns[:expanded] %>
```

- [ ] **Step 4: Restructure `_line_threads`** — replace `app/views/comments/_line_threads.html.erb` entirely:

```erb
<% composable = local_assigns[:composable] %>
<% if composable || collapsed.any? || outdated.any? %>
  <div class="anchor-strip <%= local_assigns[:wrapper_class] %> flex flex-col gap-2">
    <div id="<%= anchor.dom_id %>_line_threads" class="flex flex-col gap-2">
      <% collapsed.each do |comment| %>
        <%= render "comments/thread", comment: comment, line_badge: :collapsed %>
      <% end %>
      <% outdated.each do |comment| %>
        <%= render "comments/thread", comment: comment, line_badge: :outdated %>
      <% end %>
    </div>
    <% if composable %>
      <%= render "comments/compose", anchor: anchor, line_pin: true, expanded: local_assigns[:expanded] %>
    <% end %>
  </div>
<% end %>
```

(The strip keeps `anchor-strip`, so comment mode ignores hover/click inside it. Without `@candidate` every map is nil → `composable` false and no threads exist → version pages render nothing, as before.)

- [ ] **Step 5: Wire the three call sites** — each already has the map and partition in scope; add the new locals.

`app/views/endpoints/_endpoint_diff.html.erb` line 59:

```erb
      <%= render "comments/line_threads", anchor: response_output_anchor(endpoint, line.code), collapsed: resp_line_comments[:collapsed], outdated: resp_line_comments[:outdated], composable: !resp_map.nil?, expanded: expanded, wrapper_class: line.after_present? ? "col-start-2" : "col-start-1" %>
```

`app/views/specs/_responses.html.erb` line 13:

```erb
    <%= render "comments/line_threads", anchor: response_output_anchor(endpoint, line.code), collapsed: resp_line_comments[:collapsed], outdated: resp_line_comments[:outdated], composable: !resp_map.nil?, expanded: expanded, wrapper_class: "" %>
```

`app/views/versions/_endpoints_and_entities.html.erb` line 126 (entities are never collapsible → `expanded: true`; removed entities are not composable):

```erb
            <%= render "comments/line_threads", anchor: entity_root_anchor(entity), collapsed: entity_line_comments[:collapsed], outdated: entity_line_comments[:outdated], composable: entity.annotation != "removed" && !entity_map.nil?, expanded: true, wrapper_class: entity.annotation == "removed" ? "mt-3 w-1/2 pr-1" : "mt-3 w-1/2 ml-auto pl-1" %>
```

- [ ] **Step 6: Rewrite the Stimulus controller** — replace `app/javascript/controllers/comment_mode_controller.js` with:

```js
import { Controller } from "@hotwired/stimulus"

// Figma-style comment mode for the candidate page. Toggled from the toolbar
// (or the "C" key). While on: the cursor becomes a 💬 pin, hovering a
// [data-comment-region] target outlines it (.anchor-highlight), and clicking
// opens that target's anchored compose form (#<dom_id>_form). Rows inside a
// [data-line-pick] tree are finer-grained targets: clicking one opens the
// block's line compose form (#<pick dom_id>_form) fed the row's canonical
// expanded-tree index; the picked row keeps its outline until the form
// closes or the comment is posted. Stays on until Esc or toggled off.
// Threads / open compose / toolbar stay interactive; other in-target
// controls (Copy cURL, Expand) are suppressed.
export default class extends Controller {
  static targets = ["button", "pin"]

  connect() {
    this.onMove = this.onMove.bind(this)
    this.onClick = this.onClick.bind(this)
    this.onKey = this.onKey.bind(this)
    this.onSubmitEnd = this.onSubmitEnd.bind(this)
    document.addEventListener("keydown", this.onKey)
    document.addEventListener("turbo:submit-end", this.onSubmitEnd)
  }

  disconnect() {
    this.deactivate()
    this.clearPick()
    document.removeEventListener("keydown", this.onKey)
    document.removeEventListener("turbo:submit-end", this.onSubmitEnd)
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
    // A pick backing an open composer survives leaving comment mode.
    if (!this.pickedForm || this.pickedForm.hidden) this.clearPick()
    document.removeEventListener("mousemove", this.onMove)
    document.removeEventListener("click", this.onClick, true)
  }

  onKey(e) {
    if (e.key === "Escape") {
      const open = e.target.closest && e.target.closest("[data-comment-form]")
      if (open) {
        open.hidden = true
        if (open === this.pickedForm) this.clearPick()
        this.buttonTarget.focus()
        return
      }
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
      if (f) {
        f.hidden = true
        if (f === this.pickedForm) this.clearPick()
      }
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

  onSubmitEnd(e) {
    if (!this.pickedForm || !e.detail.success) return
    if (e.target.closest && e.target.closest("[data-comment-form]") === this.pickedForm) this.clearPick()
  }

  pickableRow(target) {
    const row = target.closest && target.closest("[data-line-index]")
    return row && row.closest("[data-line-pick]") ? row : null
  }

  pick(row) {
    const block = row.closest("[data-line-pick]")
    const form = document.getElementById(block.getAttribute("data-line-pick") + "_form")
    if (!form) return
    this.clearPick()
    this.picked = row
    this.pickedForm = form
    row.classList.add("line-picked")
    const line = row.getAttribute("data-line-index")
    form.querySelector("input[name='comment[line]']").value = line
    form.querySelector("[data-pick-label]").textContent = "📌 " + block.getAttribute("data-line-pick-label") + " · line " + line
    this.showForm(form)
  }

  clearPick() {
    if (this.picked) this.picked.classList.remove("line-picked")
    this.picked = null
    this.pickedForm = null
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
    if (form) this.showForm(form)
  }

  showForm(form) {
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

- [ ] **Step 7: Remove the chip from the toolbar** — in `app/views/comments/_toolbar.html.erb`, delete the whole chip `<div data-comment-toolbar data-comment-mode-target="chip" …>…</div>` block (lines 12–15). The button, kbd hint, and pin span stay.

- [ ] **Step 8: Candidate-page request spec** — in `spec/requests/candidates_requests_spec.rb`, inside `describe "#show inline comment threads"`, add (same POST shape as the Stage 7 pick-metadata example):

```ruby
    it "renders a hidden line compose form per pickable block" do
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

      output_anchor = CommentAnchor.new(scope: "response", part: "output",
                                        endpoint_path: "/users", endpoint_http_verb: 0, response_code: "200")
      root_anchor = CommentAnchor.new(scope: "entity", part: "root", entity_name: "User")
      expect(response.body).to include("id=\"#{output_anchor.dom_id}_form\"")
      expect(response.body).to include("id=\"#{output_anchor.dom_id}_line_threads\"")
      expect(response.body).to include("id=\"#{root_anchor.dom_id}_form\"")
      expect(response.body).to include('name="comment[line]"')
      expect(response.body).to include('name="expanded"')
      expect(response.body).to include("data-pick-label")
    end
```

- [ ] **Step 9: Version-page non-leak** — in `spec/requests/versions_requests_spec.rb`, in the existing "does not render candidate comment threads on the version page" example, add:

```ruby
      expect(response.body).not_to include('name="comment[line]"')
      expect(response.body).not_to include("_line_threads")
```

- [ ] **Step 10: Build + run**

Run: `bin/vite build && bin/rails tailwindcss:build`
Expected: both succeed.
Run: `bundle exec rspec spec/requests/candidates_requests_spec.rb spec/requests/versions_requests_spec.rb spec/requests/endpoints_requests_spec.rb && bin/rubocop`
Expected: green, no offenses.

- [ ] **Step 11: VISUAL CHECKPOINT (user gate)** — on rc4's candidate page (`bin/dev` running):
  - Toggle comment mode; click the collapsed `User` row in `GET /users` 200 → **no chip**; the compose form opens below the response (right side) with a `📌 GET /users → 200 → output · line 4` header; the row keeps its sky outline while the form is open.
  - Pick another row → the form's header/line update, the outline moves. Click the response note/header → the whole-region compose opens instead, the pick clears.
  - Cancel / Esc closes the form and clears the outline; Esc again exits comment mode. Toggling mode off while the form is open keeps the form + outline.
  - Entity `User` tree rows open the entity root form the same way; removed targets and before sides still don't react.
  - Submitting works but the new thread only appears after a reload — that's Task 3. Version page `v4` unchanged.
  - Tune form header wording/placement per feedback.

---

### Task 3: Stream the created thread into place (Stage 6 placement)

**Files:**
- Modify: `app/views/comments/create.turbo_stream.erb`
- Modify: `spec/requests/comments_requests_spec.rb`

**Interfaces:**
- Consumes: `CommentAnchor#without_line` (Task 1), the `#<dom_id>_line_threads` container and line compose locals (Task 2), `params[:expanded]` from the form's hidden field, `comments/_inline_line_comment` (renders with `line_badge: :inlined`), `turbo_stream.after_all` (turbo-rails 2.0.16).
- Produces: the line-root turbo-stream response — inline `after` targeting `[data-line-pick="<dom_id>"] [data-line-index="<line>"]` when the block was expanded, `append` to `#<dom_id>_line_threads` with a **Collapsed** badge otherwise; compose reset; sidebar badge update (shared with the non-line branch).

- [ ] **Step 1: Rewrite the anchored-root branch** — replace the final `<% else %>` branch of `app/views/comments/create.turbo_stream.erb` (keep the reply and candidate branches untouched):

```erb
<% else %>
  <% region_anchor = @comment.anchor.without_line %>
  <% if @comment.line.nil? %>
    <%= turbo_stream.append region_anchor.dom_id do %>
      <%= render "comments/thread", comment: @comment %>
    <% end %>
    <%= turbo_stream.replace "#{region_anchor.dom_id}_form" do %>
      <%= render "comments/compose", anchor: region_anchor %>
    <% end %>
  <% else %>
    <% expanded = params[:expanded] == "true" %>
    <% if expanded %>
      <%= turbo_stream.after_all "[data-line-pick=\"#{region_anchor.dom_id}\"] [data-line-index=\"#{@comment.line}\"]" do %>
        <%= render "comments/inline_line_comment", comment: @comment %>
      <% end %>
    <% else %>
      <%= turbo_stream.append "#{region_anchor.dom_id}_line_threads" do %>
        <%= render "comments/thread", comment: @comment, line_badge: :collapsed %>
      <% end %>
    <% end %>
    <%= turbo_stream.replace "#{region_anchor.dom_id}_form" do %>
      <%= render "comments/compose", anchor: region_anchor, line_pin: true, expanded: expanded %>
    <% end %>
  <% end %>
  <% sidebar_anchor = @comment.scope == "entity" ? CommentAnchor.new(scope: "entity", part: "whole", entity_name: @comment.entity_name) : CommentAnchor.new(scope: "endpoint", part: "whole", endpoint_path: @comment.endpoint_path, endpoint_http_verb: @comment.endpoint_http_verb) %>
  <%= turbo_stream.update sidebar_count_dom_id(sidebar_anchor) do %>
    <%= comment_count_badge(comment_sidebar_count(sidebar_anchor)) %>
  <% end %>
<% end %>
```

(For a non-line root, `without_line` is the anchor itself, so that path is byte-identical to today. A fresh line comment is inline-eligible by construction; the snapshot never needs re-checking here.)

- [ ] **Step 2: Turbo-stream request specs** — in the `describe "line-anchored roots"` group from Task 1, add:

```ruby
      it "streams the thread inline after its row when the block was expanded" do
        sign_in(user)
        post project_candidate_comments_path(project.name, candidate.name),
             params: line_params.merge(expanded: "true"), as: :turbo_stream

        region = CommentAnchor.new(scope: "response", part: "output",
                                   endpoint_path: "/users", endpoint_http_verb: 0, response_code: "200")
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include('action="after"')
        expect(response.body).to include("data-line-pick=&quot;#{region.dom_id}&quot;")
        expect(response.body).to include("data-line-index=&quot;4&quot;")
        expect(response.body).to include(">Inlined<")
        expect(response.body).to include("target=\"#{region.dom_id}_form\"")
      end

      it "streams the thread into the below-block container when the block was collapsed" do
        sign_in(user)
        post project_candidate_comments_path(project.name, candidate.name),
             params: line_params.merge(expanded: "false"), as: :turbo_stream

        region = CommentAnchor.new(scope: "response", part: "output",
                                   endpoint_path: "/users", endpoint_http_verb: 0, response_code: "200")
        expect(response.body).to include("action=\"append\" target=\"#{region.dom_id}_line_threads\"")
        expect(response.body).to include(">Collapsed<")
        expect(response.body).to include("target=\"#{region.dom_id}_form\"")
        expect(response.body).not_to include('action="after"')
      end
```

(The `targets` selector is HTML-attribute-escaped in the stream tag, hence the `&quot;` assertions.)

- [ ] **Step 3: Run the specs, then the suite**

Run: `bundle exec rspec spec/requests/comments_requests_spec.rb`
Expected: green.
Run: `bundle exec rspec && bin/rubocop`
Expected: full suite green, no offenses.

- [ ] **Step 4: VISUAL CHECKPOINT (user gate)** — on rc4's candidate page:
  - **Collapsed create:** comment mode on, pick the collapsed `User` row (line 4), submit → the thread appears **below the response** with a sky **Collapsed** badge; the form closes reset (empty textarea, no stale 📌 header on next open); the row outline clears; the sidebar 💬 count bumps; comment mode is still on.
  - **Expand** the endpoint → that thread relocates inline under the `User` row (badge **Inlined**) — the Stage 6 render takes over.
  - **Expanded create:** with the card expanded, pick a row inside the expanded `User` subtree (e.g. `email: string`), submit → the thread appears **inline directly under that row** immediately, badge **Inlined**. Collapse → it relocates below as **Collapsed**.
  - **Entity create:** pick `name: string` in the `User` entity tree, submit → inline under the row immediately (entities are always expanded).
  - Reply on a just-created line thread works; hovering the thread still highlights nothing extra (line threads carry no region highlight — unchanged).
  - Version page `v4`: byte-clean, no forms/containers.

---

### Task 4: Verification + proposed commit

- [ ] **Step 1: Full verification**

Run: `bundle exec rspec && bin/rubocop && bundle exec brakeman -q`
Expected: suite green, no offenses, no new warnings.

- [ ] **Step 2: Stage and propose** — `git add -A`, show `git status` + a short diffstat, and propose the commit message:

```
Add candidate commenting Stage 8: line pick creates anchored comments
```

Commit **only on the user's explicit go-ahead** (straight to main, no Co-Authored-By, per workflow).

---

## Self-review notes (traceability)

- **Pick opens the anchor's compose form `#<dom_id>_form` (part output/root)** — no such form existed before this stage (regions only had part-`whole` composes); Task 2 renders it per pickable block keyed to the exact `data-line-pick` value, and `pick()` opens it (user instruction).
- **Form fed the captured canonical `line`** — JS copies the row's `data-line-index` into `comment[line]`; the server re-derives nothing client-side (Stage 7 contract).
- **Server permits `:line` and sets `anchor_snapshot` server-side to the whole current output at pin time** — Task 1 permit + `current_output(latest_version)`; `anchor_snapshot` absent from all permit lists; forged-snapshot spec guards it.
- **Created thread renders per Stage 6 placement** — fresh by construction, so expanded (form-stamped flag) → inline `after` the row; collapsed → below-block append with **Collapsed** badge; the next full render (expand/collapse/reload) re-places it through the existing Stage 6 pipeline.
- **Chip removed / repurposed** — chip markup + targets deleted; its label info became the form's 📌 header (Task 2 Steps 6–7).
- **Conventions kept** — id contract (`_form`, `_line_threads` suffixes on the region dom_id), `anchor-strip` on the new surface, right-side pinning, one composer open at a time, version pages byte-clean, sidebar badge live-update unchanged for line roots (scope-level counting already includes them).
