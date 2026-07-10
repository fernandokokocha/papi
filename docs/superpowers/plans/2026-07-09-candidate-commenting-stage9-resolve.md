# Candidate Commenting Stage 9: resolve (close / reopen threads) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the candidate author mark a comment thread **resolved** (collapsing it to a one-line summary in place) and later **reopen** it; replying to a resolved thread auto-reopens it. Sidebar counts and Stage 6 placement are unchanged.

**Architecture:** Resolution is a thread-level (root comment) state — two new `comments` columns (`resolved_at`, `resolved_by_id`). A singular nested `resolution` resource (`create` = resolve, `destroy` = reopen) responds with a turbo-stream that replaces the whole thread (`dom_id(comment)`) with its freshly-rendered state. `_thread` branches on `comment.resolved?`: a collapsed summary strip (click to expand, Reopen button) vs. the full body (with a Resolve button in the footer). Because the server can't know a line thread's live placement badge, the resolve / reopen / reply forms carry the current `line_badge` as a hidden field, echoed back into the re-render. A `Comment` `after_create` callback clears the parent's resolution on reply.

## Global Constraints (copied from the design spec)

- **Resolution is thread-level** — only root comments (`parent_id` nil) carry it; replies never inherit it (`resolved_at`/`resolved_by_id` are NOT added to `ANCHOR_ATTRIBUTES`) and a reply carrying a resolution is invalid (kept as a defensive net — user ruling).
- **Only the candidate author resolves/reopens** — `CommentPolicy#resolve?` = `@user == @record.candidate.author`; one method used for both actions ("keep the door open" — widening later is a one-line change).
- **Resolution is orthogonal to Stage 6 placement** (Inlined/Collapsed/Outdated) — a resolved thread keeps its placement, only its body is swapped for the summary.
- **`line_badge` carry (Ruling A)** — resolve/reopen/reply forms carry the current placement badge as a hidden field; the server echoes it into the thread re-render. Non-line threads carry nothing → no badge.
- **Sidebar 💬 counts stay untouched** — `comment_threads_by_anchor` / `comment_count_badge` / `comment_sidebar_count` count all threads regardless of resolution. No counting code changes.
- **Auto-reopen on reply** — posting any reply on a resolved thread clears the parent's resolution (applies to anyone who can reply, per `create?`).
- **Version pages stay byte-clean** — resolve controls render only in commentable context (gated by `policy(comment).resolve?`, and threads never render on version pages anyway).
- **DB change via `bin/rails dev:setup`** — edit the existing `create_comments` migration in place, no new migration file (project workflow).
- **Turbo Drive is off** — resolve/reopen `button_to` forms opt in per-element with `form: { data: { turbo: true } }` (mirrors `comments/_form`).
- Tailwind classes as complete literal strings; White & Sky palette; double quotes; 2-space indent; lean views (no ceremony comments, no guards for invariant-impossible states beyond the one ruled in).
- No TDD-first ordering: specs alongside/after impl; no "verify it fails" steps.
- Git: do NOT commit or branch. Stage with `git add -A`; a single Stage 9 commit is proposed at the end. Pause at the Task 3 and Task 4 visual gates.

---

### Task 1: Data model — columns, `resolved?`, reply guard, auto-reopen callback

**Files:**
- Modify: `db/migrate/20260703000001_create_comments.rb`
- Modify: `app/models/comment.rb`
- Modify: `spec/factories/comments.rb`
- Modify: `spec/models/comment_spec.rb`

**Interfaces:**
- Produces:
  - `comments.resolved_at` (datetime, nullable), `comments.resolved_by_id` (integer FK → users, nullable).
  - `Comment#resolved?` → Boolean (`resolved_at.present?`).
  - `Comment#resolved_by` → `User` or nil.
  - `Comment#reopened_parent?` → Boolean — true on a reply whose `after_create` cleared a resolved parent (Task 4's stream branches on it).
  - `:resolved` factory trait (root, `resolved_at` set, `resolved_by` a user).

- [ ] **Step 1: Add the columns** — in `db/migrate/20260703000001_create_comments.rb`, after `t.text :anchor_snapshot`:

```ruby
      t.text :anchor_snapshot

      t.datetime :resolved_at
      t.references :resolved_by, null: true, foreign_key: { to_table: :users }
```

- [ ] **Step 2: Model** — in `app/models/comment.rb`, add the association (next to the other `belongs_to`), the callback registration (next to `before_validation`), the validation (next to the others), and the four methods. Place the association after `belongs_to :parent`:

```ruby
  belongs_to :resolved_by, class_name: "User", optional: true
```

Add after the existing `before_validation :inherit_parent_anchor, if: :parent`:

```ruby
  after_create :reopen_parent, if: :reply?
```

Add after `validate :anchor_valid`:

```ruby
  validate :reply_not_resolved
```

Add `resolved?` next to `root?`/`reply?`:

```ruby
  def resolved?
    resolved_at.present?
  end

  def reopened_parent?
    @reopened_parent == true
  end
```

Add to the `private` section:

```ruby
  def reply_not_resolved
    return unless reply?
    errors.add(:resolved_at, "cannot be set on a reply") if resolved_at.present? || resolved_by_id.present?
  end

  def reopen_parent
    return unless parent&.resolved?
    parent.update_columns(resolved_at: nil, resolved_by_id: nil)
    @reopened_parent = true
  end
```

(`reopen_parent` uses `update_columns` deliberately — it must not re-run validations/callbacks on the parent, and the reply itself is already persisted. The in-memory `parent` object is mutated too, so Task 4's re-render sees it open.)

- [ ] **Step 3: Factory trait** — in `spec/factories/comments.rb`, add inside the `factory :comment` block (after the `:reply` trait):

```ruby
    trait :resolved do
      resolved_at { Time.current }
      association :resolved_by, factory: :user
    end
```

- [ ] **Step 4: Model specs** — in `spec/models/comment_spec.rb`, add:

```ruby
  describe "resolution" do
    it "#resolved? reflects resolved_at" do
      expect(FactoryBot.build(:comment)).not_to be_resolved
      expect(FactoryBot.build(:comment, :resolved)).to be_resolved
    end

    it "rejects a reply that carries a resolution" do
      root = FactoryBot.create :comment
      reply = FactoryBot.build :comment, candidate: root.candidate, parent: root, resolved_at: Time.current
      expect(reply).not_to be_valid
      expect(reply.errors[:resolved_at]).to be_present
    end

    it "auto-reopens a resolved parent when a reply is created" do
      root = FactoryBot.create :comment, :resolved
      expect(root).to be_resolved

      reply = FactoryBot.create :comment, candidate: root.candidate, parent: root
      expect(reply.reopened_parent?).to be true
      expect(root.reload).not_to be_resolved
      expect(root.resolved_by_id).to be_nil
    end

    it "does not flag reopened_parent when the parent was already open" do
      root = FactoryBot.create :comment
      reply = FactoryBot.create :comment, candidate: root.candidate, parent: root
      expect(reply.reopened_parent?).to be false
    end
  end
```

- [ ] **Step 5: Apply the schema** — run `bin/rails dev:setup` (rebuilds the dev DB from the edited migration and reseeds; routine local reset).

- [ ] **Step 6: Run the specs**

Run: `bundle exec rspec spec/models/comment_spec.rb`
Expected: green.

- [ ] **Step 7: Checkpoint** — report results. No commit; the server path lands in Task 2.

---

### Task 2: Policy, route, controller — the resolve / reopen server path

**Files:**
- Modify: `app/policies/comment_policy.rb`
- Modify: `config/routes.rb:11`
- Create: `app/controllers/resolutions_controller.rb`
- Create: `app/views/resolutions/create.turbo_stream.erb`
- Create: `app/views/resolutions/destroy.turbo_stream.erb`
- Modify: `app/helpers/comments_helper.rb`
- Create: `spec/policies/comment_policy_spec.rb`
- Create: `spec/requests/resolutions_requests_spec.rb`

**Interfaces:**
- Consumes: `Comment#resolved?`, `Candidate#author`, `Candidate#comment_threads_by_anchor`, `dom_id`.
- Produces:
  - `CommentPolicy#resolve?` → Boolean.
  - Routes `project_candidate_comment_resolution_path(project, candidate, comment)` — POST (create), DELETE (destroy).
  - `CommentsHelper#line_badge_param` → `:inlined`/`:collapsed`/`:outdated`/nil (whitelisted from `params[:line_badge]`), used by the resolution + reply re-renders.
  - Both turbo-stream responses `replace` `dom_id(@comment)` with `comments/thread` (Task 3 renders the resolved vs open branches).

- [ ] **Step 1: Policy** — in `app/policies/comment_policy.rb`, add:

```ruby
  def resolve?
    @user == @record.candidate.author
  end
```

- [ ] **Step 2: Route** — in `config/routes.rb`, replace line 11 (`resources :comments, only: [ :create ]`) with:

```ruby
      resources :comments, only: [ :create ] do
        resource :resolution, only: [ :create, :destroy ]
      end
```

- [ ] **Step 3: `line_badge_param` helper** — in `app/helpers/comments_helper.rb`, add (near the other small helpers):

```ruby
  # Whitelisted placement badge echoed from a resolve/reopen/reply form so a
  # thread re-render keeps its Inlined/Collapsed/Outdated pill (the server
  # can't recompute placement — it depends on the client's expanded state).
  def line_badge_param
    %w[inlined collapsed outdated].include?(params[:line_badge]) ? params[:line_badge].to_sym : nil
  end
```

- [ ] **Step 4: Controller** — create `app/controllers/resolutions_controller.rb`:

```ruby
class ResolutionsController < ApplicationController
  before_action :set_comment

  def create
    authorize @comment, :resolve?
    @comment.update(resolved_at: Time.current, resolved_by: Current.user)
    respond_with_thread
  end

  def destroy
    authorize @comment, :resolve?
    @comment.update(resolved_at: nil, resolved_by: nil)
    respond_with_thread
  end

  private

  def set_comment
    @project = Project.find_by!(name: params[:project_name])
    @candidate = Candidate.find_by!(name: params[:candidate_name], project: @project)
    @comment = @candidate.comments.find(params[:comment_id])
  end

  def respond_with_thread
    @comment_threads_by_anchor = @candidate.comment_threads_by_anchor
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to project_candidate_path(@project.name, @candidate.name) }
    end
  end
end
```

(`update` is non-bang on purpose: a resolution POSTed at a reply id fails the Task 1 validation, leaves the row unchanged, and re-renders it harmlessly — no 500. `@comment_threads_by_anchor` is set so the re-render's `policy` and badge helpers behave as on the full page.)

- [ ] **Step 5: Turbo-stream templates** — both replace the thread with its re-rendered self. Create `app/views/resolutions/create.turbo_stream.erb`:

```erb
<%= turbo_stream.replace dom_id(@comment) do %>
  <%= render "comments/thread", comment: @comment, line_badge: line_badge_param %>
<% end %>
```

Create `app/views/resolutions/destroy.turbo_stream.erb` with the identical body:

```erb
<%= turbo_stream.replace dom_id(@comment) do %>
  <%= render "comments/thread", comment: @comment, line_badge: line_badge_param %>
<% end %>
```

- [ ] **Step 6: Policy spec** — create `spec/policies/comment_policy_spec.rb`:

```ruby
require "rails_helper"

describe CommentPolicy do
  let(:group) { FactoryBot.create :group }
  let(:author) { FactoryBot.create :user, group: group }
  let(:other) { FactoryBot.create :user, group: group }
  let(:project) { FactoryBot.create :project, group: group }
  let(:candidate) { FactoryBot.create :candidate, project: project, author: author }
  let(:comment) { FactoryBot.create :comment, candidate: candidate, author: author }

  describe "#resolve?" do
    it "allows the candidate author" do
      expect(described_class.new(author, comment).resolve?).to be true
    end

    it "denies another group member" do
      expect(described_class.new(other, comment).resolve?).to be false
    end
  end
end
```

- [ ] **Step 7: Request spec** — create `spec/requests/resolutions_requests_spec.rb`:

```ruby
require "rails_helper"

describe "Resolutions requests", type: :request do
  let(:group) { FactoryBot.create :group, name: "Test group" }
  let(:author) { FactoryBot.create :user, email_address: "author@example.com", password: "password", group: group }
  let(:other) { FactoryBot.create :user, email_address: "other@example.com", password: "password", group: group }
  let(:project) { FactoryBot.create :project, name: "project", group: group }
  let(:candidate) { FactoryBot.create :candidate, project: project, name: "rc1", author: author }
  let(:thread) { FactoryBot.create :comment, candidate: candidate, author: author }

  describe "#create (resolve)" do
    it "marks the thread resolved and replaces it via turbo-stream" do
      sign_in(author)
      post project_candidate_comment_resolution_path(project.name, candidate.name, thread), as: :turbo_stream

      expect(thread.reload).to be_resolved
      expect(thread.resolved_by).to eq(author)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("action=\"replace\" target=\"#{ActionView::RecordIdentifier.dom_id(thread)}\"")
      expect(response.body).to include("Resolved by author@example.com")
    end

    it "echoes the line_badge into the re-render" do
      sign_in(author)
      post project_candidate_comment_resolution_path(project.name, candidate.name, thread),
           params: { line_badge: "collapsed" }, as: :turbo_stream
      expect(response.body).to include(">Collapsed<")
    end

    it "forbids a non-author" do
      sign_in(other)
      post project_candidate_comment_resolution_path(project.name, candidate.name, thread)
      expect(thread.reload).not_to be_resolved
    end
  end

  describe "#destroy (reopen)" do
    let(:thread) { FactoryBot.create :comment, :resolved, candidate: candidate, author: author }

    it "clears the resolution and re-renders the open thread" do
      sign_in(author)
      delete project_candidate_comment_resolution_path(project.name, candidate.name, thread), as: :turbo_stream

      expect(thread.reload).not_to be_resolved
      expect(response.body).to include("action=\"replace\" target=\"#{ActionView::RecordIdentifier.dom_id(thread)}\"")
      expect(response.body).not_to include("Resolved by")
    end
  end
end
```

- [ ] **Step 8: Run the specs**

Run: `bundle exec rspec spec/policies/comment_policy_spec.rb spec/requests/resolutions_requests_spec.rb`
Expected: green. (These exercise the server path against the Task 3 `_thread` render, so they also confirm the rendering wiring once Task 3 lands. If run before Task 3, the "Resolved by" / "Collapsed" assertions fail — run this step after Task 3, or accept the red until then.)

> **Sequencing note:** the resolve/reopen re-render depends on Task 3's `_thread` branches. Implement Task 2's code, then Task 3, and run Step 8 after Task 3. The policy spec is green immediately.

- [ ] **Step 9: Checkpoint** — report results.

---

### Task 3: Rendering — collapsed summary, Resolve/Reopen buttons, expand controller, form badge carry

**Files:**
- Create: `app/views/comments/_placement_badge.html.erb`
- Create: `app/views/comments/_thread_body.html.erb`
- Modify: `app/views/comments/_thread.html.erb`
- Modify: `app/views/comments/_comment.html.erb`
- Modify: `app/views/comments/_reply_form.html.erb`
- Modify: `app/views/comments/_form.html.erb`
- Create: `app/javascript/controllers/resolved_thread_controller.js`
- Modify: `spec/requests/candidates_requests_spec.rb`

**Interfaces:**
- Consumes: `Comment#resolved?`, `#resolved_by`, `#resolved_at`, `#replies`, Pundit's `policy` view helper, `project_candidate_comment_resolution_path`, `dom_id`.
- Produces:
  - `comments/_placement_badge` — the Inlined/Collapsed/Outdated pill (extracted from `_comment`; reused by the summary).
  - `comments/_thread_body` — the open thread (comment + replies + reply form + Resolve button); rendered directly when open, and hidden inside the summary when resolved.
  - `_thread` branches on `resolved?`; the resolved branch is a `resolved-thread` Stimulus controller with a `body` target.
  - Reply form carries `hidden_field_tag :line_badge` when a `line_badge` local is present.

- [ ] **Step 1: Extract the placement badge** — create `app/views/comments/_placement_badge.html.erb`:

```erb
<% case line_badge
   when :inlined %>
  <span class="ml-auto shrink-0 bg-gray-100 text-gray-600 border border-gray-200 text-[10px] font-semibold px-2 py-0.5 rounded-full cursor-help" title="<%= comment.anchor.label %>">Inlined</span>
<% when :collapsed %>
  <span class="ml-auto shrink-0 bg-sky-50 text-sky-700 border border-sky-200 text-[10px] font-semibold px-2 py-0.5 rounded-full cursor-help" title="<%= comment.anchor.label %> — expand to view inline">Collapsed</span>
<% when :outdated %>
  <span class="ml-auto shrink-0 bg-amber-50 text-amber-700 border border-amber-200 text-[10px] font-semibold px-2 py-0.5 rounded-full cursor-help" title="<%= comment.anchor.label %> · snapshot: <%= comment.anchor_snapshot %>">Outdated</span>
<% end %>
```

- [ ] **Step 2: Use it in `_comment`** — in `app/views/comments/_comment.html.erb`, replace the three-way `<% if line_badge == :inlined %> … <% end %>` block (lines 9–15) with:

```erb
    <%= render "comments/placement_badge", comment: comment, line_badge: line_badge %>
```

(The surrounding header flex and everything else in `_comment` is unchanged; the extracted pills are byte-identical.)

- [ ] **Step 3: Extract the open thread body** — create `app/views/comments/_thread_body.html.erb`:

```erb
<% line_badge = local_assigns[:line_badge] %>
<%= render "comments/comment", comment: comment, line_badge: line_badge %>
<div id="<%= dom_id(comment, :replies) %>" class="pl-6">
  <% comment.replies.sort_by(&:created_at).each do |reply| %>
    <%= render "comments/reply", reply: reply %>
  <% end %>
</div>
<div id="<%= dom_id(comment, :reply_form) %>" class="border-t border-gray-200 p-4" data-controller="reply">
  <%= render "comments/reply_form", parent: comment, line_badge: line_badge %>
</div>
<% if policy(comment).resolve? %>
  <div class="border-t border-gray-200 px-4 py-2 flex justify-end">
    <%= button_to "Resolve thread", project_candidate_comment_resolution_path(comment.candidate.project.name, comment.candidate.name, comment),
          params: { line_badge: line_badge }, form: { data: { turbo: true } },
          class: "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50 text-xs font-medium px-3 py-1.5 rounded cursor-pointer" %>
  </div>
<% end %>
```

- [ ] **Step 4: Rewrite `_thread`** — replace `app/views/comments/_thread.html.erb` entirely:

```erb
<% line_badge = local_assigns[:line_badge] %>
<div id="<%= dom_id(comment) %>" class="bg-white border border-gray-200 border-l-4 border-l-sky-500 rounded-lg shadow-sm">
  <% if comment.resolved? %>
    <div data-controller="resolved-thread">
      <div class="flex items-center gap-2 px-4 py-2.5">
        <button type="button" data-action="resolved-thread#toggle"
                class="flex items-center gap-2 text-left flex-1 cursor-pointer"
                title="Resolved by <%= comment.resolved_by&.email_address %> at <%= comment.resolved_at.strftime("%Y-%m-%d %H:%M") %>">
          <span class="text-emerald-600">✓</span>
          <span class="text-sm text-gray-600">Resolved by <%= comment.resolved_by&.email_address %> · <%= pluralize(comment.replies.size + 1, "comment") %></span>
        </button>
        <%= render "comments/placement_badge", comment: comment, line_badge: line_badge %>
        <% if policy(comment).resolve? %>
          <%= button_to "Reopen", project_candidate_comment_resolution_path(comment.candidate.project.name, comment.candidate.name, comment),
                method: :delete, params: { line_badge: line_badge }, form: { data: { turbo: true } },
                class: "shrink-0 bg-white text-gray-700 border border-gray-300 hover:bg-gray-50 text-xs font-medium px-3 py-1.5 rounded cursor-pointer" %>
        <% end %>
      </div>
      <div data-resolved-thread-target="body" class="border-t border-gray-200" hidden>
        <%= render "comments/thread_body", comment: comment, line_badge: line_badge %>
      </div>
    </div>
  <% else %>
    <%= render "comments/thread_body", comment: comment, line_badge: line_badge %>
  <% end %>
</div>
```

(The outer `id=dom_id(comment)` is preserved so Task 2's `turbo_stream.replace` swaps the whole thread. `placement_badge` renders nothing for a non-line thread, so the summary has just the ✓ label and Reopen.)

- [ ] **Step 5: Reply form carries the badge** — replace `app/views/comments/_reply_form.html.erb`:

```erb
<button type="button" data-reply-target="trigger" data-action="reply#show"
        class="w-full text-left text-sm text-gray-400 border border-gray-300 rounded-lg px-3 py-1.5 hover:bg-gray-50 cursor-text">Reply…</button>
<div data-reply-target="form" hidden>
  <%= render "comments/form", candidate: parent.candidate, parent: parent, line_badge: local_assigns[:line_badge] %>
</div>
```

- [ ] **Step 6: `_form` emits the hidden badge field** — in `app/views/comments/_form.html.erb`, inside the `<% if parent %>` branch (after `form.hidden_field :parent_id`), add:

```erb
    <% if local_assigns[:line_badge] %>
      <%= hidden_field_tag :line_badge, local_assigns[:line_badge] %>
    <% end %>
```

- [ ] **Step 7: Stimulus controller** — create `app/javascript/controllers/resolved_thread_controller.js`:

```js
import { Controller } from "@hotwired/stimulus"

// Reveals a resolved thread's full body (comments, replies, reply form)
// when its collapsed summary is toggled. Reopening is a separate button_to.
export default class extends Controller {
  static targets = ["body"]

  toggle() {
    this.bodyTarget.hidden = !this.bodyTarget.hidden
  }
}
```

- [ ] **Step 8: Candidate-page request spec** — in `spec/requests/candidates_requests_spec.rb`, add inside `describe "#show inline comment threads"`. The candidate is created via `valid_params` (as in the group's first example), so its author is the signed-in `user`:

```ruby
    it "shows the Resolve control to the candidate author and collapses a resolved thread" do
      sign_in(user)
      post project_candidates_path(project.name), params: valid_params
      candidate = Candidate.find_by!(name: "rc1")
      candidate.comments.create!(author: user, body: "Please fix", scope: "candidate", part: "whole")
      candidate.comments.create!(author: user, body: "Done here", scope: "candidate", part: "whole",
                                 resolved_at: Time.current, resolved_by: user)

      get project_candidate_path(project.name, candidate.name)

      expect(response.body).to include("Resolve thread")
      expect(response.body).to include("Resolved by #{user.email_address}")
      expect(response.body).to include("data-controller=\"resolved-thread\"")
    end

    it "hides the Resolve control from a non-author in the same group" do
      sign_in(user)
      post project_candidates_path(project.name), params: valid_params
      candidate = Candidate.find_by!(name: "rc1")
      candidate.comments.create!(author: user, body: "Please fix", scope: "candidate", part: "whole")

      reviewer = FactoryBot.create :user, email_address: "reviewer@example.com", password: "password", group: group
      sign_in(reviewer)
      get project_candidate_path(project.name, candidate.name)

      expect(response.body).to include("Please fix")
      expect(response.body).not_to include("Resolve thread")
    end
```

- [ ] **Step 9: Build + run**

Run: `bin/vite build && bin/rails tailwindcss:build`
Expected: both succeed.
Run: `bundle exec rspec spec/requests/candidates_requests_spec.rb spec/policies/comment_policy_spec.rb spec/requests/resolutions_requests_spec.rb && bin/rubocop`
Expected: green, no offenses. (This is the point where Task 2 Step 8's render-dependent assertions pass.)

- [ ] **Step 10: VISUAL CHECKPOINT (user gate)** — on a candidate page **viewed as its author** (`bin/dev` running):
  - An open thread shows a **Resolve thread** button in its footer. Click it → the thread collapses to a `✓ Resolved by <email> · N comments` strip; a **Reopen** button sits on the right; the sidebar 💬 count is unchanged.
  - Click the summary label → the full thread expands (replies + reply form visible); click again → collapses.
  - Click **Reopen** → the thread returns to full with the Resolve button back.
  - Resolve a **line** thread (below-block or pinned): the summary keeps its placement badge (Collapsed/Outdated). Resolve/reopen an **inline** line thread with comment mode **off** (see accepted quirk).
  - A viewer who is **not** the candidate author sees resolved threads collapsed but **no** Resolve/Reopen buttons.
  - Tune summary wording / button styling per feedback.

---

### Task 4: Auto-reopen on reply — stream the reopened thread

**Files:**
- Modify: `app/views/comments/create.turbo_stream.erb`
- Modify: `spec/requests/comments_requests_spec.rb`

**Interfaces:**
- Consumes: `Comment#reopened_parent?` (Task 1), `line_badge_param` (Task 2), `comments/thread` (Task 3), `dom_id`.
- Produces: the reply branch of `create.turbo_stream` — when the reply reopened its parent, `replace` the whole parent thread (rendered open, badge echoed); otherwise today's append-reply + reset-reply-form behavior, unchanged.

- [ ] **Step 1: Branch the reply path** — in `app/views/comments/create.turbo_stream.erb`, replace the opening `<% if @comment.reply? %> … <% end %>` block (the first branch only; leave the `candidate`/`else` branches untouched) with:

```erb
<% if @comment.reply? %>
  <% if @comment.reopened_parent? %>
    <%= turbo_stream.replace dom_id(@comment.parent) do %>
      <%= render "comments/thread", comment: @comment.parent, line_badge: line_badge_param %>
    <% end %>
  <% else %>
    <%= turbo_stream.append dom_id(@comment.parent, :replies) do %>
      <%= render "comments/reply", reply: @comment %>
    <% end %>
    <%= turbo_stream.update dom_id(@comment.parent, :reply_form) do %>
      <%= render "comments/reply_form", parent: @comment.parent %>
    <% end %>
  <% end %>
```

(On reopen, `@comment.parent` is already open in memory — the callback cleared it — and `parent.replies` queries fresh, so the re-render includes this new reply. `line_badge_param` comes from the reply form's hidden field, so a reopened line thread keeps its placement badge.)

- [ ] **Step 2: Request specs** — in `spec/requests/comments_requests_spec.rb`, add inside `describe "#create"`:

```ruby
    describe "reply on a resolved thread" do
      it "auto-reopens the parent and replaces the whole thread" do
        root = FactoryBot.create :comment, :resolved, candidate: candidate, author: user
        sign_in(user)
        post project_candidate_comments_path(project.name, candidate.name),
             params: { comment: { body: "One more thing", parent_id: root.id } }, as: :turbo_stream

        expect(root.reload).not_to be_resolved
        expect(response.body).to include("action=\"replace\" target=\"#{ActionView::RecordIdentifier.dom_id(root)}\"")
        expect(response.body).to include("One more thing")
        expect(response.body).not_to include("Resolved by")
      end

      it "leaves an open thread on the normal append path" do
        root = FactoryBot.create :comment, candidate: candidate, author: user
        sign_in(user)
        post project_candidate_comments_path(project.name, candidate.name),
             params: { comment: { body: "A reply", parent_id: root.id } }, as: :turbo_stream

        expect(response.body).to include("action=\"append\" target=\"#{ActionView::RecordIdentifier.dom_id(root, :replies)}\"")
      end
    end
```

- [ ] **Step 3: Run specs, then the suite**

Run: `bundle exec rspec spec/requests/comments_requests_spec.rb`
Expected: green.
Run: `bundle exec rspec && bin/rubocop`
Expected: full suite green, no offenses.

- [ ] **Step 4: VISUAL CHECKPOINT (user gate)** — on a candidate page viewed as its author:
  - Resolve a thread, expand the summary, post a **reply** → the thread pops back **open** (summary gone, new reply visible, Resolve button back), and the reply form resets.
  - Do the same on a **line** thread → after reopening it keeps its placement (inline/below) and badge.
  - Confirm a reply on an **already-open** thread still just appends (no full-thread flash).

---

### Task 5: Verification + non-leak + proposed commit

- [ ] **Step 1: Version-page non-leak** — in `spec/requests/versions_requests_spec.rb`, in the existing "does not render candidate comment threads on the version page" example, add:

```ruby
      expect(response.body).not_to include("Resolve thread")
      expect(response.body).not_to include("resolved-thread")
```

- [ ] **Step 2: Full verification**

Run: `bundle exec rspec && bin/rubocop && bundle exec brakeman -q`
Expected: suite green, no offenses, no new warnings.

- [ ] **Step 3: Stage and propose** — `git add -A`, show `git status` + a short diffstat, and propose the commit message:

```
Add candidate commenting Stage 9: resolve / reopen threads
```

Commit **only on the user's explicit go-ahead** (straight to main, no branch, no Co-Authored-By, per workflow).

---

## Accepted / out of scope

- **Inline line threads in comment mode:** `_inline_line_comment` carries no `anchor-strip`, so with comment mode **on** a click on its Resolve/Reopen/Reply controls is swallowed by the picker (opens the region compose) — same pre-existing behavior as its reply controls. Resolve those with comment mode off. Below-block, pinned, region, and candidate threads work in either mode. Not changing Stage 8's inline surface here.
- **Resolution granularity:** whole-thread only; no per-reply resolution (guarded by the Task 1 validation).
- **No audit trail** beyond `resolved_by` / `resolved_at` (last resolver wins; reopen clears both). No "resolved at / by whom" history.
- **Expand state is client-only**, non-persisted (like other local reveal state); a full re-render (resolve/reopen/reload) returns a resolved thread to its collapsed default.
- **A resolution POSTed at a reply id** is a no-op (non-bang `update` + the reply-not-resolved validation) — no error surface; the UI never offers it.
- **Sidebar counts** deliberately unchanged (design ruling): resolving never moves a badge number.

## Self-review notes (traceability)

- **Only the candidate author resolves** → `CommentPolicy#resolve?` (Task 2 Step 1), gating both the buttons (Task 3 Steps 3–4) and the controller (Task 2 Step 4); request + policy specs cover author-yes / other-no.
- **Collapse to one-line summary** → `_thread` resolved branch (Task 3 Step 4) + `resolved-thread` toggle (Step 7); full body extracted to `_thread_body` so open and hidden-inside-summary render identically.
- **Reopen** → DELETE `resolution` (Task 2), Reopen `button_to` (Task 3 Step 4).
- **Sidebar counts untouched** → no change to `comment_threads_by_anchor` / count helpers; asserted implicitly (no counting code in this plan).
- **Auto-reopen on reply** → `after_create :reopen_parent` (Task 1) + reply-branch stream (Task 4); `reopened_parent?` drives replace-vs-append; specs cover both.
- **line_badge carry (Ruling A)** → hidden field on resolve/reopen (`button_to params:`) and reply (`hidden_field_tag`, Task 3 Steps 3–6) forms; `line_badge_param` whitelists and echoes it (Task 2 Step 3) into every re-render.
- **Reply-can't-be-resolved net** → `reply_not_resolved` validation (Task 1) + spec; kept per user ruling.
- **Version pages byte-clean** → controls gated on `policy(comment).resolve?`; threads never render on version pages; non-leak assertion (Task 5 Step 1).
- **Conventions kept** → id contract (`dom_id(comment)` replace target preserved), Turbo opt-in per form, White & Sky button palette, lean views.
