# Candidate Commenting Stage 5: "＋ comment" affordances → pinned threads (write) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a group member create a pinned root thread on an endpoint / entity / response target by hovering it, clicking a "＋ comment" affordance, and posting — reusing Stage 3's controller/policy/Turbo write path via a new anchor-aware create path.

**Architecture:** `CommentAnchor` gains `from_params` / `to_columns` / `dom_id`, so a form can carry a logical anchor and the controller can persist it. Every anchored target renders an **always-present per-anchor container** (`id = anchor.dom_id`) holding its existing threads plus a hover-revealed compose form; the create Turbo Stream appends the new root into that same `anchor.dom_id`. The compose form reuses the existing `reply` controller for its toggle; a tiny `reveal` controller hides the "＋" until the target row/card is hovered.

**Tech Stack:** Rails 8, Hotwire (Turbo Streams + Stimulus), Tailwind CSS v4, RSpec, FactoryBot.

## Global Constraints

- White & Sky palette from `CLAUDE.md`; double quotes; 2-space indent.
- Tailwind classes must be **complete literal strings** — never interpolated fragments (`@source inline()` if a runtime-dynamic class is unavoidable).
- Comments never render on version pages (`versions/show`) — spec non-goal. The "＋" affordance and compose form appear **only in candidate context** (`@candidate` present); threads-only rendering on version pages must stay byte-for-byte unchanged.
- Stimulus controllers auto-register via `eagerLoadControllersFrom` in `app/javascript/controllers/index.js` — dropping a `*_controller.js` file is enough; **no `index.js` edit**.
- No TDD ordering (user workflow): write specs alongside/after the implementation in the same task; **no "verify it fails" steps**.
- Line-anchored creation is **out of scope** (Stages 6–8): `line` stays `nil`. Resolve is Stage 9.
- Git: do NOT commit autonomously. A single Stage 5 commit is proposed to the user at the very end.
- Each task ends with a user checkpoint; UI tasks get a visual gate in the running dev app. Do not run the whole plan autonomously to the end.

## Canonical create-part per region (design ruling — "placement is the only part signal")

Each affordance always creates **one** canonical part for its region; regions still *display* every part they already showed in Stage 4:

| Region (render site) | scope | create part | displays parts |
| --- | --- | --- | --- |
| below-card endpoint strip | `endpoint` | `whole` | `whole` |
| endpoint Note strip | `endpoint` | `note` | `note` |
| response row strip | `response` | `whole` | `whole`, `note`, `output` |
| below-card entity strip | `entity` | `whole` | `whole`, `root` |

Output/root-precise creation stays deferred (a label may be reintroduced later only if note-vs-output proves confusing).

---

### Task 1: `CommentAnchor` creation methods — `from_params`, `to_columns`, `dom_id`

The spec names these three methods but only `key` / `errors` exist today. Pure value-object additions, testable in isolation.

**Files:**
- Modify: `app/models/comment_anchor.rb`
- Modify: `spec/models/comment_anchor_spec.rb`

**Interfaces:**
- Consumes: nothing new (`RULES`, `key` already exist).
- Produces:
  - `CommentAnchor.from_params(params)` → `CommentAnchor`. Reads string keys `scope, part, endpoint_path, endpoint_http_verb, entity_name, response_code`; defaults `scope`→`"candidate"`, `part`→`"whole"` when blank; coerces verb to Integer; blanks → `nil`; `line` always `nil`. Accepts an `ActionController::Parameters` or a plain Hash.
  - `CommentAnchor#to_columns` → `Hash` of the seven anchor columns (`scope, part, line, endpoint_path, endpoint_http_verb, entity_name, response_code`) for `assign_attributes`.
  - `CommentAnchor#dom_id` → stable `String` id derived from `key` (MD5 digest — the key contains slash-bearing paths, so a digest, not a slug). Tasks 2–4 use it for both the container id and the Turbo Stream target.

- [ ] **Step 1: Add the three methods to `app/models/comment_anchor.rb`**

Add `require "digest/md5"` at the top of the file, then inside the class:

```ruby
  def self.from_params(params)
    new(
      scope: params[:scope].presence || "candidate",
      part: params[:part].presence || "whole",
      endpoint_path: params[:endpoint_path].presence,
      endpoint_http_verb: params[:endpoint_http_verb].presence&.to_i,
      entity_name: params[:entity_name].presence,
      response_code: params[:response_code].presence
    )
  end

  def to_columns
    {
      scope: scope, part: part, line: line,
      endpoint_path: endpoint_path, endpoint_http_verb: endpoint_http_verb,
      entity_name: entity_name, response_code: response_code
    }
  end

  def dom_id
    "comment_anchor_#{Digest::MD5.hexdigest(key.map(&:to_s).join(""))}"
  end
```

- [ ] **Step 2: Add examples to `spec/models/comment_anchor_spec.rb`**

```ruby
  describe ".from_params" do
    it "defaults to the candidate/whole anchor when scope and part are blank" do
      anchor = CommentAnchor.from_params({ "body" => "hi" })

      expect(anchor.scope).to eq("candidate")
      expect(anchor.part).to eq("whole")
      expect(anchor.errors).to be_empty
    end

    it "builds an endpoint anchor and coerces the verb to an integer" do
      anchor = CommentAnchor.from_params(
        "scope" => "endpoint", "part" => "note",
        "endpoint_path" => "/users", "endpoint_http_verb" => "0"
      )

      expect(anchor.scope).to eq("endpoint")
      expect(anchor.part).to eq("note")
      expect(anchor.endpoint_path).to eq("/users")
      expect(anchor.endpoint_http_verb).to eq(0)
      expect(anchor.errors).to be_empty
    end

    it "leaves irrelevant identity columns nil" do
      anchor = CommentAnchor.from_params("scope" => "entity", "part" => "whole", "entity_name" => "User")

      expect(anchor.entity_name).to eq("User")
      expect(anchor.endpoint_path).to be_nil
      expect(anchor.response_code).to be_nil
    end
  end

  describe "#to_columns" do
    it "returns every anchor column, with line nil" do
      anchor = CommentAnchor.new(scope: "response", part: "output", endpoint_path: "/users", endpoint_http_verb: 0, response_code: "200")

      expect(anchor.to_columns).to eq(
        scope: "response", part: "output", line: nil,
        endpoint_path: "/users", endpoint_http_verb: 0,
        entity_name: nil, response_code: "200"
      )
    end
  end

  describe "#dom_id" do
    it "is stable for equal anchors and differs by part" do
      whole = CommentAnchor.new(scope: "endpoint", part: "whole", endpoint_path: "/users", endpoint_http_verb: 0)
      whole_again = CommentAnchor.new(scope: "endpoint", part: "whole", endpoint_path: "/users", endpoint_http_verb: 0)
      note = CommentAnchor.new(scope: "endpoint", part: "note", endpoint_path: "/users", endpoint_http_verb: 0)

      expect(whole.dom_id).to eq(whole_again.dom_id)
      expect(whole.dom_id).not_to eq(note.dom_id)
      expect(whole.dom_id).to match(/\Acomment_anchor_[0-9a-f]{32}\z/)
    end
  end
```

- [ ] **Step 3: Run the specs**

Run: `bundle exec rspec spec/models/comment_anchor_spec.rb`
Expected: all green.

- [ ] **Step 4: Checkpoint** — report results to the user. No commit.

---

### Task 2: Anchor-aware write path (controller + form + Turbo Stream)

Teach the create path to accept an anchor from the form and route the Turbo append to the anchor's container. No visible affordance yet (Task 3), so this task is **request-spec gated**.

**Files:**
- Modify: `app/controllers/comments_controller.rb`
- Modify: `app/views/comments/_form.html.erb`
- Modify: `app/views/comments/create.turbo_stream.erb`
- Modify: `app/views/candidates/show.html.erb` (line 67 — pass the candidate anchor to the root form)
- Modify: `spec/requests/comments_requests_spec.rb`

**Interfaces:**
- Consumes: `CommentAnchor.from_params` / `#to_columns` / `#dom_id` (Task 1).
- Produces:
  - `comments/_form` gains an optional `anchor:` local (a `CommentAnchor`). For a **root** form it renders hidden fields `scope, part, endpoint_path, endpoint_http_verb, entity_name, response_code` from the anchor (defaulting to the candidate/whole anchor when the local is omitted). Reply forms (`parent` present) are unchanged — only `parent_id` is sent. Task 3's `comments/_compose` calls it with the region anchor.
  - Turbo Stream contract: an **anchored** root appends into `dom_id("<anchor.dom_id>")` and resets the compose form container `"<anchor.dom_id>_form"` by re-rendering `comments/compose`. Candidate-level roots keep the Stage 3 behavior (`candidate_comment_threads` / `new_comment_form` / `no_comments_message`).

- [ ] **Step 1: Controller reads the anchor for roots**

In `app/controllers/comments_controller.rb`, replace the body of `create` above `authorize` and the `comment_params` method:

```ruby
  def create
    @project = Project.find_by!(name: params[:project_name])
    @candidate = Candidate.find_by!(name: params[:candidate_name], project: @project)
    @comment = @candidate.comments.new(comment_params)
    @comment.author = Current.user
    @comment.assign_attributes(CommentAnchor.from_params(anchor_params).to_columns) if @comment.parent_id.blank?
    authorize @comment

    if @comment.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to project_candidate_path(@project.name, @candidate.name) }
      end
    else
      redirect_to project_candidate_path(@project.name, @candidate.name), alert: "Comment could not be posted."
    end
  end

  private

  def comment_params
    params.require(:comment).permit(:body, :parent_id)
  end

  def anchor_params
    params.require(:comment).permit(:scope, :part, :endpoint_path, :endpoint_http_verb, :entity_name, :response_code)
  end
```

Anchor columns are kept out of `comment_params` on purpose: replies never mass-assign an anchor (the `inherit_parent_anchor` callback owns it), and roots get a normalized anchor via `from_params`. A forged/malformed anchor still fails `Comment#anchor_valid` → the existing `alert` path, and the comment is always nested under the authorized `@candidate` — no new cross-candidate surface.

- [ ] **Step 2: `_form` renders anchor hidden fields for roots**

Rewrite `app/views/comments/_form.html.erb`:

```erb
<% anchor = local_assigns[:anchor] || CommentAnchor.new(scope: "candidate", part: "whole") %>
<%= form_with model: Comment.new, url: project_candidate_comments_path(candidate.project.name, candidate.name), data: { turbo: true } do |form| %>
  <% if parent %>
    <%= form.hidden_field :parent_id, value: parent.id %>
  <% else %>
    <%= form.hidden_field :scope, value: anchor.scope %>
    <%= form.hidden_field :part, value: anchor.part %>
    <%= form.hidden_field :endpoint_path, value: anchor.endpoint_path %>
    <%= form.hidden_field :endpoint_http_verb, value: anchor.endpoint_http_verb %>
    <%= form.hidden_field :entity_name, value: anchor.entity_name %>
    <%= form.hidden_field :response_code, value: anchor.response_code %>
  <% end %>
  <%= form.text_area :body, rows: 3, required: true,
        placeholder: parent ? "Write a reply…" : "Leave a comment…",
        class: "w-full border border-gray-300 rounded-lg p-3 text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-sky-500" %>
  <div class="flex justify-end gap-2 mt-2">
    <% if parent %>
      <button type="button" data-action="reply#cancel" class="bg-white text-gray-700 border border-gray-300 hover:bg-gray-50 text-sm font-medium px-4 py-2 rounded cursor-pointer">Cancel</button>
    <% end %>
    <%= form.submit parent ? "Reply" : "Comment", class: "bg-sky-600 hover:bg-sky-700 text-white text-sm font-medium px-4 py-2 rounded cursor-pointer" %>
  </div>
<% end %>
```

Note `parent` may be unset in some callers, so read it defensively is not needed — every current caller passes `parent:` (candidate form passes `parent: nil`, reply form passes the comment). Keep `parent` referenced directly.

- [ ] **Step 3: Candidate root form passes the candidate anchor**

In `app/views/candidates/show.html.erb` line 67, make the anchor explicit (behavior-preserving — `_form` defaults to the same anchor, but explicit keeps intent obvious):

```erb
    <%= render "comments/form", candidate: @candidate, parent: nil, anchor: CommentAnchor.new(scope: "candidate", part: "whole") %>
```

- [ ] **Step 4: Turbo Stream routes anchored roots to their container**

Rewrite `app/views/comments/create.turbo_stream.erb`:

```erb
<% if @comment.reply? %>
  <%= turbo_stream.append dom_id(@comment.parent, :replies) do %>
    <%= render "comments/reply", reply: @comment %>
  <% end %>
  <%= turbo_stream.update dom_id(@comment.parent, :reply_form) do %>
    <%= render "comments/reply_form", parent: @comment.parent %>
  <% end %>
<% elsif @comment.scope == "candidate" %>
  <%= turbo_stream.remove "no_comments_message" %>
  <%= turbo_stream.append "candidate_comment_threads" do %>
    <%= render "comments/thread", comment: @comment %>
  <% end %>
  <%= turbo_stream.update "new_comment_form" do %>
    <%= render "comments/form", candidate: @candidate, parent: nil, anchor: CommentAnchor.new(scope: "candidate", part: "whole") %>
  <% end %>
<% else %>
  <%= turbo_stream.append @comment.anchor.dom_id do %>
    <%= render "comments/thread", comment: @comment %>
  <% end %>
  <%= turbo_stream.update "#{@comment.anchor.dom_id}_form" do %>
    <%= render "comments/compose", anchor: @comment.anchor %>
  <% end %>
<% end %>
```

(`comments/compose` is created in Task 3. Task 2's specs assert the response body targets the right ids; the partial render is exercised at Task 3's visual gate.)

- [ ] **Step 5: Request specs for the anchored write path**

Append inside `describe "#create"` in `spec/requests/comments_requests_spec.rb`:

```ruby
    it "creates an endpoint-anchored root from anchor params" do
      sign_in(user)
      post project_candidate_comments_path(project.name, candidate.name),
           params: { comment: { body: "Pin me to GET /users", scope: "endpoint", part: "whole", endpoint_path: "/users", endpoint_http_verb: "0" } }

      comment = Comment.last
      expect(comment.scope).to eq("endpoint")
      expect(comment.part).to eq("whole")
      expect(comment.endpoint_path).to eq("/users")
      expect(comment.endpoint_http_verb).to eq(0)
      expect(comment.line).to be_nil
      expect(comment.root?).to be true
    end

    it "rejects an anchor that violates the scope/part matrix" do
      sign_in(user)
      expect {
        post project_candidate_comments_path(project.name, candidate.name),
             params: { comment: { body: "Bad", scope: "entity", part: "output", entity_name: "User" } }
      }.not_to change(Comment, :count)
      expect(flash[:alert]).to eq("Comment could not be posted.")
    end
```

- [ ] **Step 6: Run the comments specs**

Run: `bundle exec rspec spec/requests/comments_requests_spec.rb spec/models/comment_anchor_spec.rb`
Expected: green (including the pre-existing candidate-level and reply examples — the bare-body root still defaults to `candidate`/`whole`).

- [ ] **Step 7: Checkpoint** — report results to the user. No commit. Note that the affordance/compose UI arrives in Task 3, so there is nothing to click in the browser yet.

---

### Task 3: Inline "＋ comment" affordance + live create (visible trigger)

Replace the six `comments/inline_threads` render sites with a `comments/_anchor_region` partial that always renders a per-anchor container (threads + a compose form) in candidate context, and renders threads-only elsewhere. The "＋" trigger is plainly visible in this task; hover-reveal is Task 4. Reuses the `reply` controller for the compose toggle.

**Files:**
- Create: `app/views/comments/_anchor_region.html.erb`
- Create: `app/views/comments/_compose.html.erb`
- Delete: `app/views/comments/_inline_threads.html.erb` (all callers move to `_anchor_region`)
- Modify: `app/views/versions/_endpoints_and_entities.html.erb` (2 sites, lines 99 & 121)
- Modify: `app/views/endpoints/_endpoint_diff.html.erb` (note strip + response strip)
- Modify: `app/views/endpoints/_endpoint_new.html.erb` (note strip; response strip is via `specs/_responses`)
- Modify: `app/views/endpoints/_endpoint_removed.html.erb` (note strip; response strip via `specs/_responses`)
- Modify: `app/views/specs/_responses.html.erb` (response strip)
- Modify: `app/controllers/endpoints_controller.rb` (set `@candidate` alongside the anchor map)
- Modify: `spec/requests/candidates_requests_spec.rb`, `spec/requests/versions_requests_spec.rb`, `spec/requests/endpoints_requests_spec.rb`

**Interfaces:**
- Consumes: `comment_threads_for` (Stage 4 helper), `CommentAnchor.new(...)`, `anchor.dom_id` (Task 1), `comments/_form` with `anchor:` (Task 2), `comments/_thread` (Stage 2/3), the existing `reply` controller.
- Produces:
  - `comments/_anchor_region` — locals `anchor:` (`CommentAnchor`, the region's **create** anchor), `threads:` (array of root comments to display), `wrapper_class:` (**position/margins only** — the gray "strip" skin is applied internally, only when threads are present). Renders nothing unless `@candidate` is present or `threads.any?`. Container element `id = anchor.dom_id` is the Turbo append target; the compose block's id is `"<anchor.dom_id>_form"`. Renders the compose form only when `@candidate` is present.
  - `comments/_compose` — local `anchor:`; renders the visible "＋ comment" trigger and a hidden `comments/_form` (toggled by the `reply` controller). Reads `@candidate` for the form's `candidate:`.
  - `EndpointsController#show` now assigns `@candidate` (same strictly-scoped candidate it already resolves) so the shared partials know they're in candidate context after an Expand/Collapse re-render.

- [ ] **Step 1: Create `app/views/comments/_compose.html.erb`**

```erb
<button type="button" data-reply-target="trigger" data-reveal-target="trigger" data-action="reply#show"
        class="text-left text-sm text-sky-600 hover:text-sky-700 font-medium cursor-pointer">＋ comment</button>
<div data-reply-target="form" hidden class="mt-2">
  <%= render "comments/form", candidate: @candidate, parent: nil, anchor: anchor %>
</div>
```

(`data-reveal-target` is inert until Task 4 registers the `reveal` controller — harmless now. The compose lives inside `_anchor_region`, which supplies the `reply` controller wrapper.)

- [ ] **Step 2: Create `app/views/comments/_anchor_region.html.erb`**

```erb
<% if @candidate || threads.any? %>
  <div class="<%= local_assigns[:wrapper_class] %>"
       data-controller="anchor-highlight reveal"
       data-action="mouseenter->anchor-highlight#highlight mouseleave->anchor-highlight#unhighlight">
    <% if threads.any? %>
      <div id="<%= anchor.dom_id %>" class="flex flex-col gap-3 bg-gray-50 border border-gray-200 rounded-lg p-3">
        <% threads.each do |thread| %>
          <%= render "comments/thread", comment: thread %>
        <% end %>
      </div>
    <% else %>
      <div id="<%= anchor.dom_id %>" class="flex flex-col gap-3"></div>
    <% end %>
    <% if @candidate %>
      <div id="<%= anchor.dom_id %>_form" class="mt-1" data-controller="reply">
        <%= render "comments/compose", anchor: anchor %>
      </div>
    <% end %>
  </div>
<% end %>
```

Notes:
- The empty threads `<div>` still renders (with `anchor.dom_id`) so the very first Turbo append has a target even when the region started empty.
- The gray strip skin (`bg-gray-50 border … p-3`) is applied **only** around a non-empty thread list, so empty regions show just the "＋" — no gray band under every quiet card.
- `data-controller="reply"` wraps the compose block; the `reply` controller's `trigger`/`form` targets live inside `_compose`.

- [ ] **Step 3: Delete `_inline_threads` and move the two below-card sites**

Delete `app/views/comments/_inline_threads.html.erb`.

In `app/views/versions/_endpoints_and_entities.html.erb` line 99 (endpoint below-card), replace the `inline_threads` render with:

```erb
            <%= render "comments/anchor_region",
                  anchor: CommentAnchor.new(scope: "endpoint", part: "whole", endpoint_path: endpoint.path, endpoint_http_verb: Endpoint.http_verbs[endpoint.http_verb]),
                  threads: comment_threads_for("endpoint", endpoint: endpoint, part: "whole"),
                  wrapper_class: endpoint.annotation == "removed" ? "mt-3 w-1/2 pr-1" : "mt-3 w-1/2 ml-auto pl-1" %>
```

Line 121 (entity below-card) becomes:

```erb
            <%= render "comments/anchor_region",
                  anchor: CommentAnchor.new(scope: "entity", part: "whole", entity_name: entity.name),
                  threads: comment_threads_for("entity", entity: entity),
                  wrapper_class: entity.annotation == "removed" ? "mt-3 w-1/2 pr-1" : "mt-3 w-1/2 ml-auto pl-1" %>
```

(`wrapper_class` is now position-only; the bg/border moved into `_anchor_region`.)

- [ ] **Step 4: Note + response strips in `_endpoint_diff`**

In `app/views/endpoints/_endpoint_diff.html.erb`, the note strip (third child of the note grid) becomes:

```erb
    <%= render "comments/anchor_region",
          anchor: CommentAnchor.new(scope: "endpoint", part: "note", endpoint_path: endpoint.path, endpoint_http_verb: Endpoint.http_verbs[endpoint.http_verb]),
          threads: comment_threads_for("endpoint", endpoint: endpoint, part: "note"),
          wrapper_class: "col-start-2" %>
```

The response-row strip (inside the responses loop) becomes:

```erb
      <%= render "comments/anchor_region",
            anchor: CommentAnchor.new(scope: "response", part: "whole", endpoint_path: endpoint.path, endpoint_http_verb: Endpoint.http_verbs[endpoint.http_verb], response_code: line.code),
            threads: comment_threads_for("response", endpoint: endpoint, response_code: line.code),
            wrapper_class: line.after_present? ? "col-start-2" : "col-start-1" %>
```

- [ ] **Step 5: Note strips in the single-column card partials**

In `app/views/endpoints/_endpoint_new.html.erb`, replace the note `inline_threads` render with:

```erb
      <%= render "comments/anchor_region",
            anchor: CommentAnchor.new(scope: "endpoint", part: "note", endpoint_path: endpoint.path, endpoint_http_verb: Endpoint.http_verbs[endpoint.http_verb]),
            threads: comment_threads_for("endpoint", endpoint: endpoint, part: "note"),
            wrapper_class: "" %>
```

Apply the identical block in `app/views/endpoints/_endpoint_removed.html.erb` (same note strip location).

- [ ] **Step 6: Response strips in `specs/_responses`**

In `app/views/specs/_responses.html.erb`, replace the `inline_threads` render with:

```erb
    <%= render "comments/anchor_region",
          anchor: CommentAnchor.new(scope: "response", part: "whole", endpoint_path: endpoint.path, endpoint_http_verb: Endpoint.http_verbs[endpoint.http_verb], response_code: line.code),
          threads: comment_threads_for("response", endpoint: endpoint, response_code: line.code),
          wrapper_class: "" %>
```

(`endpoint` is already a required local here since Stage 4.)

- [ ] **Step 7: `EndpointsController#show` sets `@candidate`**

In `app/controllers/endpoints_controller.rb`, the Stage 4 block that resolves the candidate strictly within the endpoint's own project becomes (assign `@candidate` too, so re-rendered cards know they can offer the affordance):

```ruby
    candidate_project = @endpoint.version.project || @endpoint.version.candidate&.project
    @candidate = Candidate.find_by(name: params[:candidate], project: candidate_project)
    @comment_threads_by_anchor = @candidate.comment_threads_by_anchor if @candidate
```

Security shape is unchanged from Stage 4: the candidate can only come from the project `authorize @endpoint` already vouches for; absent/unknown param → `@candidate` nil → version-page rendering (no affordance, no threads). Reference: the Stage 4 plan's security note.

- [ ] **Step 8: Request specs**

**Deferred from Task 2** (needs `comments/compose`, which now exists): add this to `describe "#create"` in `spec/requests/comments_requests_spec.rb`, verifying the anchored Turbo Stream targets the anchor container:

```ruby
    it "renders a Turbo Stream targeting the anchor container when the request is turbo_stream" do
      sign_in(user)
      post project_candidate_comments_path(project.name, candidate.name),
           params: { comment: { body: "Anchored", scope: "entity", part: "whole", entity_name: "User" } },
           as: :turbo_stream

      dom_id = Comment.last.anchor.dom_id
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("action=\"append\" target=\"#{dom_id}\"")
      expect(response.body).to include("target=\"#{dom_id}_form\"")
    end
```

The Stage 4 example "renders endpoint- and entity-anchored threads on the candidate page" in `spec/requests/candidates_requests_spec.rb` still passes; add an affordance assertion as a final line:

```ruby
      expect(response.body).to include("＋ comment")
```

In `spec/requests/versions_requests_spec.rb`, the example "does not render candidate comment threads on the version page" gets a final line asserting no affordance leaks onto version pages:

```ruby
      expect(response.body).not_to include("＋ comment")
```

In `spec/requests/endpoints_requests_spec.rb`, extend the Stage 4 re-render example so the affordance appears only in candidate context. Add after its existing assertions:

```ruby
      get project_endpoint_path(project.name, endpoint.id, candidate: candidate.name)
      expect(response.body).to include("＋ comment")

      get project_endpoint_path(project.name, endpoint.id)
      expect(response.body).not_to include("＋ comment")
```

- [ ] **Step 9: Full verification**

Run: `bundle exec rspec`
Expected: entire suite green.
Run: `bin/rubocop`
Expected: no offenses.
Run: `bin/rails dev:setup` (reseed dev DB — no fixture changes, just ensures a clean state to click through).

- [ ] **Step 10: VISUAL CHECKPOINT (user gate)** — on rc4's candidate page:
  - Every endpoint/entity/response region shows a "＋ comment" affordance (plainly visible this task); quiet regions show only the affordance, **no gray band**.
  - Click "＋" under `GET /users` → the compose form opens; post → the new thread appends live under that card (right-pinned) and the form resets/collapses.
  - Post a note comment via the `PATCH /users/me` note-strip "＋" → appears under the Note section; post a response comment via a `GET /users` 200 row "＋" → appears under that row.
  - Candidate-level Conversation create/reply still works (Stage 3 unchanged).
  - Expand → Collapse a card, then post again — the affordance and live append still work after re-render.
  - Version page `v4` shows **no** "＋" affordance anywhere, including after Expand/Collapse, and its threads render exactly as before.
  - Adjust skin/spacing per feedback. No commit yet.

---

### Task 4 (revised): Comment mode — toolbar + cursor pin + click-to-place (`comment-mode` controller)

> **Two design pivots at the visual gates, both user-driven and prototype-validated. The canonical, current spec for this task is `.superpowers/sdd/task-4-brief.md` (comment mode). The Steps 1–6 further below are the SUPERSEDED hover-reveal design, kept only for history.**

**Pivot 1 (hover-reveal):** the always-visible "＋ comment" text was too noisy → replaced by a per-target hover-revealed 💬 + highlight. **Pivot 2 (comment mode — final):** per-target hover affordances still interrupted normal reading / text-selection / Copy-cURL. Final design is a **Figma-style comment mode**: a persistent toolbar on the candidate page (or `C`) toggles a mode where the cursor becomes a 💬 pin, hovering a `[data-comment-region]` target outlines it (`.anchor-highlight`), and a **click** opens that target's anchored compose form. Comment mode **stays on** (pin several) until `Esc`/toggle. At rest there is **no** affordance. `reveal_controller.js` and the per-region 💬 trigger are removed; the Task 1–3 write path, container, compose form, right-side pinning, security shape, and version-page non-leak are unchanged. Full implementation (comment-mode controller, `_toolbar`, `data-comment-region` on the six target sites, `body.commenting` CSS + pin, Turbo `replace` of the hidden form, spec markers → `data-comment-region`) is in the brief.

<details><summary>SUPERSEDED hover-reveal steps (history)</summary>

**Files:**
- Create: `app/javascript/controllers/reveal_controller.js`
- Modify: `app/views/comments/_compose.html.erb` (trigger becomes a hidden 💬 icon)

**Interfaces:**
- `reveal` controller lives on the `_anchor_region` wrapper (already carries `data-controller="anchor-highlight reveal"` from Task 3) and has a `trigger` target (the 💬 button, already tagged `data-reveal-target="trigger"` in Task 3). On connect it binds `mouseenter`/`mouseleave` to the wrapper's **preceding non-empty sibling(s)** — the hover zone, which is also the highlight target. On enter it removes `opacity-0` from the trigger AND adds `.anchor-highlight` to every zone element; on leave it reverses both. Reuses the Stage-4 `.anchor-highlight` CSS (already in `app/assets/tailwind/application.css`) — no new CSS.

- [ ] **Step 1: Create `app/javascript/controllers/reveal_controller.js`**

```js
import { Controller } from "@hotwired/stimulus"

// While the region's target (its preceding sibling cell/card) is hovered,
// reveals the 💬 compose trigger and outlines the target with the existing
// .anchor-highlight class. Relies on every strip rendering directly after
// the target it comments on, so the hover zone IS the highlight target.
export default class extends Controller {
  static targets = ["trigger"]

  connect() {
    this.zone = this.hoverZone()
    this.show = () => {
      this.triggerTargets.forEach(el => el.classList.remove("opacity-0"))
      this.zone.forEach(el => el.classList.add("anchor-highlight"))
    }
    this.hide = () => {
      this.triggerTargets.forEach(el => el.classList.add("opacity-0"))
      this.zone.forEach(el => el.classList.remove("anchor-highlight"))
    }
    this.zone.forEach(el => {
      el.addEventListener("mouseenter", this.show)
      el.addEventListener("mouseleave", this.hide)
    })
  }

  disconnect() {
    this.zone.forEach(el => {
      el.removeEventListener("mouseenter", this.show)
      el.removeEventListener("mouseleave", this.hide)
    })
  }

  // Walk contiguous previous siblings collecting the region's target(s):
  // content cells/cards get collected; empty *classless* placeholder cells
  // (a missing response side renders `<div></div>`) are skipped; an empty but
  // styled row divider — or the start of the parent — ends the row.
  hoverZone() {
    const zone = []
    let el = this.element.previousElementSibling
    while (el) {
      const empty = el.children.length === 0 && el.textContent.trim() === ""
      if (empty && el.classList.length > 0) break   // row divider → stop
      if (!empty) zone.push(el)                      // content cell / card
      el = el.previousElementSibling                 // empty+classless placeholder → skip
    }
    return zone
  }
}
```

- [ ] **Step 2: `_compose` trigger becomes a hidden 💬 icon**

Rewrite `app/views/comments/_compose.html.erb` so the trigger is a small 💬 button, hidden by default (`opacity-0`), revealed by the controller on target hover (and via keyboard `focus`). No text label. The 💬 sits at the right of the region (matches right-side pinning), so it aligns with where the thread strip appears.

```erb
<div class="flex justify-end">
  <button type="button" data-reply-target="trigger" data-reveal-target="trigger" data-action="reply#show"
          title="Comment"
          class="opacity-0 focus:opacity-100 text-base leading-none px-1 cursor-pointer">💬</button>
</div>
<div data-reply-target="form" hidden class="mt-2">
  <%= render "comments/form", candidate: @candidate, parent: nil, anchor: anchor %>
</div>
```

(The `_anchor_region.html.erb` wrapper already carries `data-controller="anchor-highlight reveal"` and this trigger already carries `data-reveal-target="trigger"` from Task 3 — no change needed there. `opacity-0` reserves only a small icon-height slot per region when unhovered, so quiet regions stay quiet.)

- [ ] **Step 3: Build assets**

Run: `bin/vite build` (and `bin/rails tailwindcss:build` if the dev watcher is not running) so the new controller and the `opacity-0` utility are picked up.

- [ ] **Step 4: Verify** — `bundle exec rspec` still green. Note the Task 3 request specs assert `include("＋ comment")` / `not_to include("＋ comment")`; those strings no longer exist. **Update them to assert on a stable non-visual marker instead** — the compose form's post URL is a poor choice (present in reply forms too), so assert on the region container/form id which only anchored regions emit. Concretely, in each of the three specs replace the `"＋ comment"` string with the affordance's `title="Comment"` marker (present once per region, only in candidate context): `include("title=\"Comment\"")` on the candidate/endpoint candidate-context renders, and `not_to include("title=\"Comment\"")` on the version-page and no-candidate endpoint renders. Re-run those three request specs to confirm green.

- [ ] **Step 5: VISUAL CHECKPOINT (user gate)** — on rc4:
  - No persistent affordance text/icons cluttering the page at rest — quiet regions look clean.
  - Hovering a target **instantly** outlines it (sky) **and** shows a 💬 for that region only: hovering one response row lights that row + its 💬 (not neighbors'); hovering the Note area lights the note cells + note 💬; hovering an endpoint/entity card outlines the card + its below-card 💬.
  - Clicking the 💬 opens the compose form; posting still appends live and the form collapses back to the hidden 💬.
  - Existing thread strips still highlight their target on strip-hover (Stage 4 behavior intact).
  - Works after Expand → Collapse (controller reconnects and rebinds). Version page `v4` stays clean (no 💬, no highlight-on-hover affordance).
  - Tune icon size/placement per feedback.

- [ ] **Step 6: Propose the commit** — suggest `Add candidate commenting Stage 5: hover-to-comment affordances create pinned threads` and commit **only on the user's go-ahead**.

</details>

---

## Self-review notes (traceability to the design spec)

- **Spec "Stage 5: ＋ comment affordances → create pinned threads (reuses stage 3 plumbing + anchor)"** — Tasks 1–4 cover anchor plumbing (1), write path (2), affordance + live create (3), hover polish (4).
- **`CommentAnchor.from_params` / `to_columns`** (spec Components) — Task 1.
- **Reuses Stage 3 write path** — Task 2 extends `CommentsController#create` / `_form` / `create.turbo_stream.erb` rather than adding a new controller; replies untouched.
- **Anchor validity enforced** (spec scope × part matrix) — relies on the existing `Comment#anchor_valid`; Task 2 request spec covers a matrix violation.
- **Comment-UI conventions memory** — right-side pinning preserved (position-only `wrapper_class`, removed → left); no part chips (canonical create-part table, placement is the signal); per-region hover; strict-project candidate resolution for re-renders (Task 3 Step 7).
- **Non-goals respected** — no line anchoring (`line` stays nil), no resolve, no edit/delete, no version-page comments (candidate-context gate).
