# Candidate Commenting Stage 4: Inline Anchored Threads (render-only) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render comment threads pinned to endpoint cards, entity cards, and response rows on the candidate page, looked up from an in-memory anchor map built via `CommentAnchor`.

**Architecture:** `Candidate#comment_threads_by_anchor` loads all comments once and groups roots by `anchor_key`. A `CommentsHelper#comment_threads_for` helper reads that map (an ivar) and probes every valid part for a scope via `CommentAnchor`, returning `[]` when no map was loaded — which is how the version page (which shares `_endpoints_and_entities`) stays thread-free. Endpoint- and entity-scope threads render *below* their cards, outside the Expand/Collapse re-render container; response-scope threads render under their response row *inside* the card, so `EndpointsController#show` rebuilds the map from a new `candidate` URL param that only the candidate page sends.

**Explicitly out of scope (later stages):** "＋ comment" affordances (Stage 5), line-anchored threads and Outdated markers (Stage 6), resolve (Stage 9). This stage is render-only — the only interactivity is replying to an inline thread, which Stage 3's plumbing already provides (replies inherit the parent's anchor via `Comment#inherit_parent_anchor`, and the reply Turbo Stream targets `dom_id(parent, :replies)` wherever the thread renders).

## Global Constraints

- White & Sky palette from `CLAUDE.md`; double quotes; 2-space indent.
- Tailwind classes must be complete literal strings — never interpolated fragments.
- Comments never render on version pages (`versions/show`) — spec non-goal.
- No TDD ordering (user workflow): write specs alongside/after the implementation in the same task; no "verify it fails" steps.
- Git: do NOT commit autonomously. A single Stage 4 commit is proposed to the user at the very end.
- Each task ends with a user checkpoint; UI tasks get a visual gate in the running dev app.

---

### Task 1: Anchor-map lookup layer (`Candidate#comment_threads_by_anchor` + `CommentsHelper#comment_threads_for`)

**Files:**
- Modify: `app/models/candidate.rb`
- Create: `app/helpers/comments_helper.rb`
- Create: `spec/models/candidate_spec.rb`
- Create: `spec/helpers/comments_helper_spec.rb`

**Interfaces:**
- Consumes: `Comment#anchor_key` / `#root?` (Stage 2), `CommentAnchor.new(...).key` and `CommentAnchor::RULES` (Stage 2).
- Produces:
  - `Candidate#comment_threads_by_anchor` → `Hash{anchor_key array => [root Comment, ...] sorted by created_at}` with `:author` and `replies: :author` preloaded.
  - `CommentsHelper#comment_threads_for(scope, endpoint: nil, entity: nil, response_code: nil)` → sorted `[root Comment, ...]`; `[]` when `@comment_threads_by_anchor` is unset. Tasks 2 and 3 call this from views.

- [ ] **Step 1: Add `Candidate#comment_threads_by_anchor`**

In `app/models/candidate.rb`, add the public method:

```ruby
def comment_threads_by_anchor
  comments.includes(:author, replies: :author)
    .select(&:root?)
    .sort_by(&:created_at)
    .group_by(&:anchor_key)
end
```

- [ ] **Step 2: Create `app/helpers/comments_helper.rb`**

Note the verb integer comes from the enum mapping (`Endpoint.http_verbs`), not `http_verb_before_type_cast` — the latter can return the unsaved string on freshly built records.

```ruby
module CommentsHelper
  # Root comment threads pinned to the given target, across all of the
  # scope's valid parts (line-anchored threads are excluded; they render
  # elsewhere from Stage 6 on). Returns [] outside candidate-page context.
  def comment_threads_for(scope, endpoint: nil, entity: nil, response_code: nil)
    return [] unless @comment_threads_by_anchor

    CommentAnchor::RULES.fetch(scope)[:parts].flat_map do |part|
      key = CommentAnchor.new(
        scope: scope, part: part,
        endpoint_path: endpoint&.path,
        endpoint_http_verb: endpoint && Endpoint.http_verbs[endpoint.http_verb],
        entity_name: entity&.name,
        response_code: response_code
      ).key
      @comment_threads_by_anchor.fetch(key, [])
    end.sort_by(&:created_at)
  end
end
```

- [ ] **Step 3: Write `spec/models/candidate_spec.rb`**

```ruby
require "rails_helper"

describe Candidate do
  describe "#comment_threads_by_anchor" do
    let(:candidate) { FactoryBot.create(:candidate) }

    it "groups root comments by anchor key and excludes replies" do
      root = FactoryBot.create(:comment, :endpoint_scope, candidate: candidate)
      reply = FactoryBot.create(:comment, candidate: candidate, parent: root, body: "A reply")
      candidate_level = FactoryBot.create(:comment, candidate: candidate)

      map = candidate.comment_threads_by_anchor

      expect(map[[ "endpoint", "/users", 0, nil, nil, "whole", nil ]]).to eq([ root ])
      expect(map[[ "candidate", nil, nil, nil, nil, "whole", nil ]]).to eq([ candidate_level ])
      expect(map.values.flatten).not_to include(reply)
    end

    it "sorts threads within an anchor by creation time" do
      newer = FactoryBot.create(:comment, candidate: candidate, created_at: 2.days.ago)
      older = FactoryBot.create(:comment, candidate: candidate, created_at: 5.days.ago)

      map = candidate.comment_threads_by_anchor

      expect(map[[ "candidate", nil, nil, nil, nil, "whole", nil ]]).to eq([ older, newer ])
    end
  end
end
```

- [ ] **Step 4: Write `spec/helpers/comments_helper_spec.rb`**

```ruby
require "rails_helper"

describe CommentsHelper, type: :helper do
  let(:candidate) { FactoryBot.create(:candidate) }
  let(:endpoint) { FactoryBot.create(:endpoint, path: "/users", http_verb: "verb_get") }
  let(:entity) { FactoryBot.create(:entity, name: "User") }

  def assign_map
    assign(:comment_threads_by_anchor, candidate.comment_threads_by_anchor)
  end

  it "returns [] when no anchor map is assigned" do
    FactoryBot.create(:comment, :endpoint_scope, candidate: candidate)

    expect(helper.comment_threads_for("endpoint", endpoint: endpoint)).to eq([])
  end

  it "finds endpoint threads across parts, sorted by creation time" do
    note_thread = FactoryBot.create(:comment, :endpoint_scope, candidate: candidate, part: "note", created_at: 2.days.ago)
    whole_thread = FactoryBot.create(:comment, :endpoint_scope, candidate: candidate, created_at: 1.day.ago)
    assign_map

    expect(helper.comment_threads_for("endpoint", endpoint: endpoint)).to eq([ note_thread, whole_thread ])
  end

  it "does not match a different endpoint" do
    FactoryBot.create(:comment, :endpoint_scope, candidate: candidate)
    other = FactoryBot.create(:endpoint, path: "/tasks", http_verb: "verb_get")
    assign_map

    expect(helper.comment_threads_for("endpoint", endpoint: other)).to eq([])
  end

  it "finds entity threads by name" do
    thread = FactoryBot.create(:comment, :entity_scope, candidate: candidate)
    assign_map

    expect(helper.comment_threads_for("entity", entity: entity)).to eq([ thread ])
  end

  it "finds response threads by endpoint identity and code" do
    thread = FactoryBot.create(:comment, :response_scope, candidate: candidate)
    assign_map

    expect(helper.comment_threads_for("response", endpoint: endpoint, response_code: "200")).to eq([ thread ])
    expect(helper.comment_threads_for("response", endpoint: endpoint, response_code: "404")).to eq([])
  end
end
```

- [ ] **Step 5: Run the new specs**

Run: `bundle exec rspec spec/models/candidate_spec.rb spec/helpers/comments_helper_spec.rb`
Expected: all green.

- [ ] **Step 6: Checkpoint** — report results to the user before moving on. No commit.

---

### Task 2: Below-card threads (endpoint + entity scope) + fixtures

**Files:**
- Create: `app/views/comments/_inline_threads.html.erb`
- Modify: `app/controllers/candidates_controller.rb` (replace `@candidate_comment_threads` load, lines 12–15)
- Modify: `app/views/candidates/show.html.erb` (Conversation section, lines 57–63)
- Modify: `app/views/versions/_endpoints_and_entities.html.erb` (thread strips below each endpoint/entity card)
- Modify: `test/fixtures/comments.yml` (anchored seed threads)
- Modify: `spec/requests/candidates_requests_spec.rb`, `spec/requests/versions_requests_spec.rb`

**Interfaces:**
- Consumes: `comment_threads_for(scope, endpoint:, entity:)` from Task 1; existing `comments/_thread` partial (renders one root + replies + reply form).
- Produces: `comments/_inline_threads` partial with locals `threads:` (array of root comments) and optional `wrapper_class:` — renders nothing when `threads` is empty. Task 3 reuses it for response rows. Controller ivar contract: `@comment_threads_by_anchor` set on candidate pages only.

- [ ] **Step 1: Create `app/views/comments/_inline_threads.html.erb`**

Each thread reuses the Stage 2/3 `comments/_thread` card; a small chip names the part when the thread pins something narrower than the whole card:

```erb
<% if threads.any? %>
  <div class="<%= local_assigns[:wrapper_class] %> flex flex-col gap-3">
    <% threads.each do |thread| %>
      <div>
        <% unless thread.part == "whole" %>
          <div class="mb-1">
            <span class="bg-gray-100 text-gray-600 border border-gray-200 text-xs font-semibold px-2 py-0.5 rounded-full">on <%= thread.part %></span>
          </div>
        <% end %>
        <%= render "comments/thread", comment: thread %>
      </div>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 2: Load the anchor map in `CandidatesController#show`**

Replace lines 12–15 of `app/controllers/candidates_controller.rb` (the `@candidate_comment_threads` assignment) with:

```ruby
    @comment_threads_by_anchor = @candidate.comment_threads_by_anchor
```

- [ ] **Step 3: Point the Conversation section at the helper**

In `app/views/candidates/show.html.erb`, the section currently iterates `@candidate_comment_threads` (lines 57–63). Replace the section body so it uses the helper (DOM ids must stay — the Stage 3 Turbo Streams target them):

```erb
  <% candidate_threads = comment_threads_for("candidate") %>
  <div id="candidate_comment_threads" class="flex flex-col gap-6">
    <% candidate_threads.each do |thread| %>
      <%= render "comments/thread", comment: thread %>
    <% end %>
    <% if candidate_threads.empty? %>
      <p id="no_comments_message" class="text-sm text-gray-500">No comments yet.</p>
    <% end %>
  </div>
```

- [ ] **Step 4: Render thread strips below endpoint and entity cards**

In `app/views/versions/_endpoints_and_entities.html.erb`:

Inside each `#endpoint-...` wrapper div (after the closing `<% end %>` of the annotation branches, still inside the `div id="endpoint-..."`, currently around line 90), add:

```erb
            <%= render "comments/inline_threads", threads: comment_threads_for("endpoint", endpoint: endpoint), wrapper_class: "mt-3 ml-8" %>
```

Inside each `#entity-...` wrapper div (after the entity annotation branches, currently around line 111), add:

```erb
            <%= render "comments/inline_threads", threads: comment_threads_for("entity", entity: entity), wrapper_class: "mt-3 ml-8" %>
```

Placement rationale: these strips sit *outside* the `data-endpoint-target="container"` div, so Expand/Collapse (which replaces that container's innerHTML) never wipes them. On the version page `@comment_threads_by_anchor` is unset, the helper returns `[]`, and nothing renders.

Note: for a **removed** endpoint, `endpoint` is the base version's record — its path/verb still match the comment's logical anchor, which is exactly the point (anchors survive removal).

- [ ] **Step 5: Add anchored fixtures to `test/fixtures/comments.yml`**

Append (candidate4/rc4 diffs project1v3 → project1v4; `GET /users` = verb 0, `PATCH /users/me` = verb 3, removed `DELETE /users/me` = verb 4; entity `User` changed in v4):

```yaml
c4_users_list_root:
  candidate: candidate4
  author: one
  body: "Pagination looks right, but should total include soft-deleted users?"
  scope: endpoint
  endpoint_path: /users
  endpoint_http_verb: 0
  part: whole
  created_at: 2025-04-02 10:00:00

c4_users_list_reply:
  candidate: candidate4
  author: two
  parent: c4_users_list_root
  body: "No — total counts active users only."
  scope: endpoint
  endpoint_path: /users
  endpoint_http_verb: 0
  part: whole
  created_at: 2025-04-02 10:20:00

c4_users_update_note:
  candidate: candidate4
  author: two
  body: "The note should list which fields are editable."
  scope: endpoint
  endpoint_path: /users/me
  endpoint_http_verb: 3
  part: note
  created_at: 2025-04-02 11:00:00

c4_users_delete_removed:
  candidate: candidate4
  author: one
  body: "Goodbye DELETE /users/me — account deactivation replaces it."
  scope: endpoint
  endpoint_path: /users/me
  endpoint_http_verb: 4
  part: whole
  created_at: 2025-04-02 11:30:00

c4_user_entity_root:
  candidate: candidate4
  author: one
  body: "avatar_url should be nullable — not every user uploads one."
  scope: entity
  entity_name: User
  part: root
  created_at: 2025-04-03 09:00:00

c4_users_list_200_output:
  candidate: candidate4
  author: two
  body: "items is now [User] inside a wrapper object — clients must adapt."
  scope: response
  endpoint_path: /users
  endpoint_http_verb: 0
  response_code: "200"
  part: output
  created_at: 2025-04-03 09:30:00
```

(Fixtures bypass the `inherit_parent_anchor` callback, so the reply repeats its parent's anchor columns explicitly — same convention as the Stage 2 fixtures. The response-scoped fixture renders under a response row only after Task 3; that's expected.)

- [ ] **Step 6: Add request specs**

Append to the top-level describe in `spec/requests/candidates_requests_spec.rb`:

```ruby
  describe "#show inline comment threads" do
    it "renders endpoint- and entity-anchored threads on the candidate page" do
      sign_in(user)
      post project_candidates_path(project.name), params: valid_params
      candidate = Candidate.find_by!(name: "rc1")
      candidate.comments.create!(author: user, body: "Endpoint thread body", scope: "endpoint", part: "whole", endpoint_path: "/", endpoint_http_verb: 0)
      candidate.comments.create!(author: user, body: "Entity thread body", scope: "entity", part: "root", entity_name: "User")

      get project_candidate_path(project.name, candidate.name)

      expect(response.body).to include("Endpoint thread body")
      expect(response.body).to include("Entity thread body")
    end
  end
```

Append inside `describe "#show"` in `spec/requests/versions_requests_spec.rb` (that file has no `valid_params`; build the data with factories like its other examples):

```ruby
    it "does not render candidate comment threads on the version page" do
      merged_candidate = FactoryBot.create(:candidate, project: project, aasm_state: "merged")
      merged_version = FactoryBot.create(:version, candidate: merged_candidate, project: project)
      FactoryBot.create(:endpoint, version: merged_version, path: "/users", http_verb: "verb_get")
      merged_candidate.comments.create!(author: user, body: "Endpoint thread body", scope: "endpoint", part: "whole", endpoint_path: "/users", endpoint_http_verb: 0)

      sign_in(user)
      get project_version_path(project.name, merged_version.name)

      expect(response.status).to eq(200)
      expect(response.body).not_to include("Endpoint thread body")
    end
```

- [ ] **Step 7: Run specs and reseed dev DB**

Run: `bundle exec rspec spec/requests/candidates_requests_spec.rb spec/requests/versions_requests_spec.rb spec/requests/comments_requests_spec.rb`
Expected: green.

Run: `bin/rails dev:setup` (reloads fixtures into dev).

- [ ] **Step 8: VISUAL CHECKPOINT (user gate)** — user opens `/projects/<project1>/candidates/rc4` and verifies: thread with reply below the `GET /users` card, "on note" chip thread below `PATCH /users/me`, thread below the removed `DELETE /users/me` card, "on root" chip thread below the `User` entity card, version page `v4` clean of all of them, and candidate-level Conversation unchanged. Adjust styling per feedback. No commit yet.

---

### Task 3: Part-accurate inline placement — note + response-row threads inside endpoint cards (Expand/Collapse-safe)

**Design amendment (user feedback at Task 2 visual gate):** a thread pinned to a part renders directly below that part, not in the below-card strip:
- endpoint `note` → strip right below the card's Note section (inside the card)
- response scope (all parts) → strip right below that response row; chips distinguish `note`/`output`
- endpoint `whole` → below-card strip (Task 2's placement, now filtered to `part: "whole"`)
- entity → below-card strip keeps both parts (the `root` block *is* the card body, so "below the root block" and "below the card" coincide); "on root" chip retained
- line placement is Stage 6.

Chips only render when a thread's part differs from what its position implies (`implied_part`, default `"whole"`).

**Design amendment 2 (user decision at the final gate):** part chips removed entirely — placement is the only part signal. `_inline_threads` renders bare threads (`threads:` + `wrapper_class:` locals only); `implied_part` no longer exists. The anchor data keeps exact parts; Stage 5's creation UI can reintroduce a label if note-vs-output under one response row ever proves confusing. Chip snippets in the steps below are superseded by this.

**Files:**
- Modify: `app/helpers/comments_helper.rb` + `spec/helpers/comments_helper_spec.rb` (optional `part:` filter)
- Modify: `app/views/comments/_inline_threads.html.erb` (`implied_part` chip logic)
- Modify: `app/views/versions/_endpoints_and_entities.html.erb` (endpoint strip → `part: "whole"`; the three `data-endpoint-url-value` URLs gain a `candidate` param)
- Modify: `app/views/endpoints/_endpoint_diff.html.erb` (note strip + response-row threads)
- Modify: `app/views/endpoints/_endpoint_new.html.erb`, `app/views/endpoints/_endpoint_removed.html.erb` (note strip; pass `endpoint:` to `specs/_responses`)
- Modify: `app/views/specs/_responses.html.erb` (per-row threads)
- Modify: `app/controllers/endpoints_controller.rb`
- Modify: `spec/requests/endpoints_requests_spec.rb`

**Interfaces:**
- Consumes: `comment_threads_for` (Task 1), `comments/_inline_threads` with `threads:` + `wrapper_class:` (Task 2), `Candidate#comment_threads_by_anchor` (Task 1).
- Produces: `comment_threads_for(scope, endpoint:, entity:, response_code:, part:)` — `part:` optional, `nil` = all of the scope's parts. `_inline_threads` gains optional `implied_part:` local (default `"whole"`). `specs/_responses` gains a required `endpoint:` local (its only callers are the two partials updated here). Endpoint show URLs carry an optional `candidate` query param.

- [ ] **Step 1: Add `part:` filter to the helper**

`comment_threads_for` in `app/helpers/comments_helper.rb` becomes:

```ruby
  def comment_threads_for(scope, endpoint: nil, entity: nil, response_code: nil, part: nil)
    return [] unless @comment_threads_by_anchor

    parts = part ? [ part ] : CommentAnchor::RULES.fetch(scope)[:parts]
    parts.flat_map do |p|
      key = CommentAnchor.new(
        scope: scope, part: p,
        endpoint_path: endpoint&.path,
        endpoint_http_verb: endpoint && Endpoint.http_verbs[endpoint.http_verb],
        entity_name: entity&.name,
        response_code: response_code
      ).key
      @comment_threads_by_anchor.fetch(key, [])
    end.sort_by(&:created_at)
  end
```

Add to `spec/helpers/comments_helper_spec.rb`:

```ruby
  it "filters to a single part when given" do
    note_thread = FactoryBot.create(:comment, :endpoint_scope, candidate: candidate, part: "note")
    whole_thread = FactoryBot.create(:comment, :endpoint_scope, candidate: candidate)
    assign_map

    expect(helper.comment_threads_for("endpoint", endpoint: endpoint, part: "whole")).to eq([ whole_thread ])
    expect(helper.comment_threads_for("endpoint", endpoint: endpoint, part: "note")).to eq([ note_thread ])
  end
```

- [ ] **Step 2: `implied_part` chip logic in `_inline_threads`**

`app/views/comments/_inline_threads.html.erb` becomes:

```erb
<% if threads.any? %>
  <div class="<%= local_assigns[:wrapper_class] %> flex flex-col gap-3">
    <% threads.each do |thread| %>
      <div>
        <% unless thread.part == local_assigns.fetch(:implied_part, "whole") %>
          <div class="mb-1">
            <span class="bg-gray-100 text-gray-600 border border-gray-200 text-xs font-semibold px-2 py-0.5 rounded-full">on <%= thread.part %></span>
          </div>
        <% end %>
        <%= render "comments/thread", comment: thread %>
      </div>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 3: Below-card endpoint strip narrows to `part: "whole"`**

In `app/views/versions/_endpoints_and_entities.html.erb`, the endpoint strip added in Task 2 becomes:

```erb
            <%= render "comments/inline_threads", threads: comment_threads_for("endpoint", endpoint: endpoint, part: "whole"), wrapper_class: "mt-3 ml-8" %>
```

The entity strip is unchanged (all parts, below the card).

- [ ] **Step 4: Note strips inside the endpoint card partials**

In `app/views/endpoints/_endpoint_diff.html.erb`, directly after the Note two-column grid (`<div class="grid grid-cols-2">…</div>` rendering `notes_diff`, before the Responses header), insert:

```erb
  <%= render "comments/inline_threads", threads: comment_threads_for("endpoint", endpoint: endpoint, part: "note"), implied_part: "note", wrapper_class: "bg-gray-50 border-t border-gray-200 p-3" %>
```

In `_endpoint_new.html.erb` (after the note div, line 22) and `_endpoint_removed.html.erb` (after the note div, line 21), insert the same line.

- [ ] **Step 5: Thread rows under responses in `_endpoint_diff`**

The responses loop (lines 42–46) becomes:

```erb
    <% responses_diff.lines.each_with_index do |line, i| %>
      <% if i > 0 %><div class="col-span-2 border-t border-gray-200"></div><% end %>
      <%= render "endpoints/response_cell", line: line, side: :before %>
      <%= render "endpoints/response_cell", line: line, side: :after, curl_verb: endpoint.verb, curl_path: endpoint.path %>
      <%= render "comments/inline_threads", threads: comment_threads_for("response", endpoint: endpoint, response_code: line.code), wrapper_class: "col-span-2 bg-gray-50 border-t border-gray-200 p-3" %>
    <% end %>
```

- [ ] **Step 6: Thread rows in `specs/_responses` (single-column added/removed cards)**

`app/views/specs/_responses.html.erb` becomes:

```erb
<div>
  <% lines.each_with_index do |line, i| %>
    <% if i > 0 %><div class="border-t border-gray-200"></div><% end %>
    <%= render "endpoints/response_cell", line: line, side: side, curl_verb: local_assigns[:curl_verb], curl_path: local_assigns[:curl_path] %>
    <%= render "comments/inline_threads", threads: comment_threads_for("response", endpoint: endpoint, response_code: line.code), wrapper_class: "bg-gray-50 border-t border-gray-200 p-3" %>
  <% end %>
</div>
```

Update its two callers to pass the endpoint:
- `_endpoint_new.html.erb`: `<%= render "specs/responses", lines: responses_diff.lines, side: :after, endpoint: endpoint, curl_verb: endpoint.verb, curl_path: endpoint.path %>`
- `_endpoint_removed.html.erb`: `<%= render "specs/responses", lines: responses_diff.lines, side: :before, endpoint: endpoint %>`

- [ ] **Step 7: Candidate param on endpoint re-render URLs**

In `app/views/versions/_endpoints_and_entities.html.erb`, all three `data-endpoint-url-value` attributes gain `candidate: @candidate&.name` (nil on version pages → param omitted → no threads on re-render there):

```erb
data-endpoint-url-value="<%= project_endpoint_path(project_name: @project.name, id: endpoint.id, candidate: @candidate&.name) %>"
data-endpoint-url-value="<%= project_endpoint_path(project_name: @project.name, id: endpoint.id, kind: 'new', candidate: @candidate&.name) %>"
data-endpoint-url-value="<%= project_endpoint_path(project_name: @project.name, id: endpoint.id, kind: 'removed', candidate: @candidate&.name) %>"
```

- [ ] **Step 8: Rebuild the anchor map in `EndpointsController#show`**

In `app/controllers/endpoints_controller.rb`, right after `authorize @endpoint`, add:

```ruby
    candidate_project = @endpoint.version.project || @endpoint.version.candidate&.project
    candidate = Candidate.find_by(name: params[:candidate], project: candidate_project)
    @comment_threads_by_anchor = candidate.comment_threads_by_anchor if candidate
```

(Security note — two earlier drafts were rejected in review: `Candidate.find_by(name: params[:candidate], project: @project)` let a user authorized for *some* endpoint load an arbitrary foreign candidate's comment map (`@project` comes from attacker-controlled `params[:project_name]`, and only `@endpoint` is authorized); deriving strictly from `@endpoint.version.candidate` closed the leak but broke removed-endpoint cards, whose endpoint objects belong to the *base* version — their threads vanished on Expand/Collapse re-render. Scoping the name lookup to the endpoint's own project fixes both: the candidate can only come from the project `authorize @endpoint` already vouches for (same group ⇒ `CandidatePolicy#show?` holds), and a removed endpoint's base version still resolves to the same project. Absent/unknown param → nil → ivar unset → helper returns `[]`, keeping version pages thread-free.)

- [ ] **Step 9: Request spec for the re-render path**

Append to `describe "#show"` in `spec/requests/endpoints_requests_spec.rb`:

```ruby
    it "renders note- and response-anchored threads only when re-rendering for a candidate page" do
      sign_in(user)
      post project_candidates_path(project.name), params: valid_params
      candidate = Candidate.find_by!(name: "rc1")
      endpoint = Endpoint.last
      candidate.comments.create!(author: user, body: "Note thread body", scope: "endpoint", part: "note", endpoint_path: "/", endpoint_http_verb: 0)
      candidate.comments.create!(author: user, body: "Response thread body", scope: "response", part: "output", endpoint_path: "/", endpoint_http_verb: 0, response_code: "200")

      get project_endpoint_path(project.name, endpoint.id, candidate: candidate.name)
      expect(response.body).to include("Note thread body")
      expect(response.body).to include("Response thread body")

      get project_endpoint_path(project.name, endpoint.id)
      expect(response.body).not_to include("Note thread body")
      expect(response.body).not_to include("Response thread body")
    end
```

- [ ] **Step 10: Full verification**

Run: `bundle exec rspec`
Expected: entire suite green.
Run: `bin/rubocop`
Expected: no offenses.

- [ ] **Step 11: VISUAL CHECKPOINT (user gate)** — on rc4's page: the `PATCH /users/me` note thread now sits directly below that card's Note section (no chip); the `GET /users` 200 row shows the "on output" thread spanning both diff columns; Expand → Collapse on those cards and the inside-card threads are still there after each re-render; the whole-endpoint thread stays below the `GET /users` card; replying to an inline thread appends live (Stage 3 plumbing); version page v4 still clean, including after Expand/Collapse there.

- [ ] **Step 12: Propose the commit** — suggest `Add candidate commenting Stage 4: inline anchored threads (render-only)` and commit **only on the user's go-ahead**.

---

### Task 4: Sidebar comment indicators (user request at Stage 4 gate)

Sidebar rows for endpoints/entities that have comment threads get a subtle `💬 n` count (n = thread count, not counting replies). Endpoint counts include response-scoped threads (and any future line-anchored ones — identity match ignores part/line). Version pages show no badges (map unset → count 0).

**Files:**
- Modify: `app/helpers/comments_helper.rb` + `spec/helpers/comments_helper_spec.rb`
- Modify: `app/views/versions/_endpoints_and_entities.html.erb` (sidebar link rows)
- Modify: `spec/requests/candidates_requests_spec.rb`, `spec/requests/versions_requests_spec.rb` (one assertion each)

**Interfaces:**
- Produces: `CommentsHelper#endpoint_comment_thread_count(endpoint)` → Integer; `CommentsHelper#entity_comment_thread_count(entity)` → Integer. Both return 0 when `@comment_threads_by_anchor` is unset.

- [ ] **Step 1: Count helpers**

Append to `app/helpers/comments_helper.rb` (anchor-key layout: `[scope, endpoint_path, endpoint_http_verb, entity_name, response_code, part, line]`):

```ruby
  def endpoint_comment_thread_count(endpoint)
    return 0 unless @comment_threads_by_anchor

    verb = Endpoint.http_verbs[endpoint.http_verb]
    @comment_threads_by_anchor.sum do |(scope, path, key_verb, *), threads|
      %w[endpoint response].include?(scope) && path == endpoint.path && key_verb == verb ? threads.size : 0
    end
  end

  def entity_comment_thread_count(entity)
    return 0 unless @comment_threads_by_anchor

    @comment_threads_by_anchor.sum do |key, threads|
      key[0] == "entity" && key[3] == entity.name ? threads.size : 0
    end
  end
```

Append to `spec/helpers/comments_helper_spec.rb`:

```ruby
  it "counts endpoint threads across parts and response codes, not replies" do
    root = FactoryBot.create(:comment, :endpoint_scope, candidate: candidate)
    FactoryBot.create(:comment, candidate: candidate, parent: root, body: "A reply")
    FactoryBot.create(:comment, :endpoint_scope, candidate: candidate, part: "note")
    FactoryBot.create(:comment, :response_scope, candidate: candidate)
    assign_map

    expect(helper.endpoint_comment_thread_count(endpoint)).to eq(3)
    other = FactoryBot.create(:endpoint, path: "/tasks", http_verb: "verb_get")
    expect(helper.endpoint_comment_thread_count(other)).to eq(0)
  end

  it "counts entity threads by name" do
    FactoryBot.create(:comment, :entity_scope, candidate: candidate)
    assign_map

    expect(helper.entity_comment_thread_count(entity)).to eq(1)
    expect(helper.entity_comment_thread_count(FactoryBot.create(:entity, name: "Task"))).to eq(0)
  end

  it "returns 0 counts when no anchor map is assigned" do
    FactoryBot.create(:comment, :endpoint_scope, candidate: candidate)

    expect(helper.endpoint_comment_thread_count(endpoint)).to eq(0)
  end
```

- [ ] **Step 2: Sidebar badges**

In `app/views/versions/_endpoints_and_entities.html.erb`, the endpoint sidebar link gains a count after the path span:

```erb
              <a href="<%= "#endpoint-#{endpoint.page_url}" %>"
                 title="<%= endpoint.name %>"
                 data-sidebar-target="link"
                 class="flex items-center gap-1.5 px-1 py-0.5 rounded <%= tint %> hover:bg-gray-50">
                <%= render "endpoints/verb_badge", verb: endpoint.verb %>
                <span class="min-w-0 truncate text-sm font-mono"><%= endpoint.path %></span>
                <% count = endpoint_comment_thread_count(endpoint) %>
                <% if count > 0 %>
                  <span class="ml-auto shrink-0 text-[10px] text-gray-500">💬 <%= count %></span>
                <% end %>
              </a>
```

The entity sidebar link becomes a flex row so the badge can right-align (was `block … truncate`; the name keeps truncating inside its own span):

```erb
          <a href="<%= "#entity-#{entity.name}" %>"
             title="<%= entity.name %>"
             data-sidebar-target="link"
             class="flex items-center gap-1.5 px-2 py-1 rounded text-sm <%= tint %> hover:bg-gray-50 hover:text-sky-700">
            <span class="min-w-0 truncate"><%= entity.name %></span>
            <% count = entity_comment_thread_count(entity) %>
            <% if count > 0 %>
              <span class="ml-auto shrink-0 text-[10px] text-gray-500">💬 <%= count %></span>
            <% end %>
          </a>
```

- [ ] **Step 3: Request assertions**

In the candidates request spec example "renders endpoint- and entity-anchored threads on the candidate page", add as a final line:

```ruby
      expect(response.body).to include("💬")
```

In the versions request spec example "does not render candidate comment threads on the version page", add as a final line:

```ruby
      expect(response.body).not_to include("💬")
```

- [ ] **Step 4: Verify** — `bundle exec rspec` fully green; `bin/rubocop` clean.

- [ ] **Step 5: Visual gate** — expected counts on rc4's sidebar per fixtures: `GET /users` 💬 2 (whole thread + response-output thread; the reply doesn't count), `PATCH /users/me` 💬 1, removed `DELETE /users/me` 💬 1, `User` entity 💬 1; no badges anywhere on v4's sidebar.

---

### Task 5: Hover-highlight the comment's anchor target (user request at final gate)

Hovering an inline thread strip highlights what it refers to. Mechanism: every strip is rendered directly after its target, so a Stimulus controller outlines the strip's previous sibling(s) — 1 by default, 2 for `_endpoint_diff` response strips (before-cell + after-cell). No anchor resolution, no ids. Candidate-level Conversation threads don't use `_inline_threads`, so they're unaffected (nothing to point at).

**Files:**
- Create: `app/javascript/controllers/anchor_highlight_controller.js`
- Modify: `app/javascript/controllers/index.js` (register, following the file's existing pattern)
- Modify: `app/views/comments/_inline_threads.html.erb` (controller + action + siblings value on the wrapper)
- Modify: `app/views/endpoints/_endpoint_diff.html.erb` (response strip passes `highlight_siblings: 2`)
- Modify: `app/assets/tailwind/application.css` (`.anchor-highlight` rule)

**Interfaces:**
- `_inline_threads` gains optional `highlight_siblings:` local (default 1).

- [ ] **Step 1: Controller**

`app/javascript/controllers/anchor_highlight_controller.js`:

```js
import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
    static values = {siblings: {type: Number, default: 1}}

    highlight() {
        this.anchorTargets().forEach(el => el.classList.add("anchor-highlight"))
    }

    unhighlight() {
        this.anchorTargets().forEach(el => el.classList.remove("anchor-highlight"))
    }

    anchorTargets() {
        const result = []
        let el = this.element
        for (let i = 0; i < this.siblingsValue; i++) {
            el = el.previousElementSibling
            if (!el) break
            result.push(el)
        }
        return result
    }
}
```

Register it in `app/javascript/controllers/index.js` exactly the way the existing controllers (e.g. `reply`, `endpoint`) are registered there.

- [ ] **Step 2: Wire the wrapper**

`app/views/comments/_inline_threads.html.erb` becomes:

```erb
<% if threads.any? %>
  <div class="<%= local_assigns[:wrapper_class] %> flex flex-col gap-3"
       data-controller="anchor-highlight"
       data-anchor-highlight-siblings-value="<%= local_assigns.fetch(:highlight_siblings, 1) %>"
       data-action="mouseenter->anchor-highlight#highlight mouseleave->anchor-highlight#unhighlight">
    <% threads.each do |thread| %>
      <%= render "comments/thread", comment: thread %>
    <% end %>
  </div>
<% end %>
```

In `app/views/endpoints/_endpoint_diff.html.erb`, only the response-row strip (the `col-span-2` one inside the responses loop) gains `highlight_siblings: 2` after `response_code: line.code`, so both diff columns of the row light up. All other call sites keep the default.

- [ ] **Step 3: Highlight style**

Append to `app/assets/tailwind/application.css`, matching the file's existing custom-class conventions:

```css
.anchor-highlight {
  outline: 2px solid var(--color-sky-400);
  outline-offset: -2px;
  border-radius: 0.5rem;
}
```

(Outline, not background: doesn't shift layout and stays visible over the emerald/red/amber row tints.)

- [ ] **Step 4: Verify** — `bundle exec rspec` green (no spec asserts the wrapper markup beyond thread bodies); `bin/vite build` or the running dev watcher picks up the new controller; `bin/rails tailwindcss:build` if the dev watcher isn't running.

- [ ] **Step 5: Visual gate** — hovering the thread under `GET /users` → 200 outlines both response cells; hovering the note thread in `PATCH /users/me` outlines the note row; hovering below-card threads outlines the whole card (endpoint and entity); hover still works after Expand → Collapse.

---

### Task 6: Right-side pinning visuals (user decision at final gate)

Comments pin to the candidate (right diff column) semantically; the visuals now say so. Response/note strips sit in the right column and hover highlights only the after-cell; below-card whole-threads right-align under the new-version half. Exception (mirroring the data model): removed endpoints/entities keep threads on their left card, and a response deleted in the candidate keeps its strip on the left under the base cell. The highlight controller becomes single-target with a skip-empty-sibling walk (an empty placeholder cell — e.g. the after-cell of a removed response — is skipped, landing on the cell with content), which also retires `highlight_siblings`.

**Files:**
- Modify: `app/javascript/controllers/anchor_highlight_controller.js`
- Modify: `app/views/comments/_inline_threads.html.erb`
- Modify: `app/views/endpoints/_endpoint_diff.html.erb`
- Modify: `app/views/versions/_endpoints_and_entities.html.erb`
- Modify: `test/fixtures/responses.yml`, `test/fixtures/comments.yml`

- [ ] **Step 1: Single-target, skip-empty controller**

Replace the entire contents of `app/javascript/controllers/anchor_highlight_controller.js` with:

```js
import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
    highlight() {
        const el = this.anchorTarget()
        if (el) el.classList.add("anchor-highlight")
    }

    unhighlight() {
        const el = this.anchorTarget()
        if (el) el.classList.remove("anchor-highlight")
    }

    anchorTarget() {
        let el = this.element.previousElementSibling
        while (el && el.children.length === 0 && el.textContent.trim() === "") {
            el = el.previousElementSibling
        }
        return el
    }
}
```

- [ ] **Step 2: Drop the siblings value from the wrapper**

In `app/views/comments/_inline_threads.html.erb`, delete the `data-anchor-highlight-siblings-value` line; keep `data-controller` and `data-action` exactly as they are. After this task `highlight_siblings` must appear nowhere in the app (grep to confirm).

- [ ] **Step 3: Right-column strips in `_endpoint_diff`**

Note strip — move it INSIDE the note grid as its third child (delete the current strip line below the grid):

```erb
  <div class="grid grid-cols-2">
    <div class="px-3 py-2 bg-white text-sm text-gray-700"><%= render "specs/text", diff: notes_diff.before %></div>
    <div class="px-3 py-2 bg-white border-l border-gray-200 text-sm text-gray-700"><%= render "specs/text", diff: notes_diff.after %></div>
    <%= render "comments/inline_threads", threads: comment_threads_for("endpoint", endpoint: endpoint, part: "note"), wrapper_class: "col-start-2 bg-gray-50 border-t border-l border-gray-200 p-3" %>
  </div>
```

Response strip — inside the responses loop, replace the current strip line (and its `highlight_siblings: 2`) with:

```erb
      <%= render "comments/inline_threads", threads: comment_threads_for("response", endpoint: endpoint, response_code: line.code), wrapper_class: line.after_present? ? "col-start-2 bg-gray-50 border-t border-gray-200 p-3" : "col-start-1 bg-gray-50 border-t border-gray-200 p-3" %>
```

(`col-start-2` puts the strip in the right column; hover's previous sibling is the after-cell. For a response deleted in the candidate the after-cell is an empty placeholder: the strip sits left and the skip-empty walk highlights the before-cell.)

- [ ] **Step 4: Below-card strips right-align by annotation**

In `app/views/versions/_endpoints_and_entities.html.erb`:

Endpoint strip becomes:

```erb
            <%= render "comments/inline_threads", threads: comment_threads_for("endpoint", endpoint: endpoint, part: "whole"), wrapper_class: endpoint.annotation == "removed" ? "mt-3 w-1/2 pr-1" : "mt-3 w-1/2 ml-auto pl-1" %>
```

Entity strip becomes:

```erb
            <%= render "comments/inline_threads", threads: comment_threads_for("entity", entity: entity), wrapper_class: entity.annotation == "removed" ? "mt-3 w-1/2 pr-1" : "mt-3 w-1/2 ml-auto pl-1" %>
```

(Both branches are complete literal class strings. The strip stays the card container's direct next sibling, so hover still outlines the whole card.)

- [ ] **Step 5: Fixtures for the new cases**

In `test/fixtures/responses.yml`, in the v3 tasks group (after `p1v3_tasks_list_403`), add — v3-only, so rc4's diff shows GET /tasks with a REMOVED 429 row:

```yaml
p1v3_tasks_list_429: { endpoint: p1v3_tasks_list, code: "429", note: "Too many requests", output: "Error" }
```

Append to `test/fixtures/comments.yml`:

```yaml
c4_audit_logs_root:
  candidate: candidate4
  author: two
  body: "New audit log listing — do we need filtering by actor from day one?"
  scope: endpoint
  endpoint_path: /audit-logs
  endpoint_http_verb: 0
  part: whole
  created_at: 2025-04-03 10:00:00

c4_tasks_list_429_removed:
  candidate: candidate4
  author: one
  body: "Dropping the 429 — rate limiting moves to the gateway."
  scope: response
  endpoint_path: /tasks
  endpoint_http_verb: 0
  response_code: "429"
  part: whole
  created_at: 2025-04-03 10:30:00
```

- [ ] **Step 6: Verify** — `bundle exec rspec` green; `bin/rails dev:setup` reseeds cleanly; `bin/vite build` + `bin/rails tailwindcss:build`.

- [ ] **Step 7: Visual gate** — on rc4: GET /users 200 thread now sits under the RIGHT column only, hover outlines just the right cell; PATCH /users/me note thread under the right note cell (hover = right cell only); whole-endpoint/entity threads right-aligned below their cards (hover = whole card); added GET /audit-logs card shows its thread right-aligned beneath it; GET /tasks now renders CHANGED with a removed 429 row — its thread sits on the LEFT under the base cell and hover outlines the left cell; removed DELETE /users/me thread left-aligned below the left card; v4 page still clean.
