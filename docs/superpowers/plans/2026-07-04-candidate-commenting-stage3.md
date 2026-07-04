# Candidate Commenting — Stage 3 (Candidate-level interactive: create + reply) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **This plan is deliberately not TDD** — write implementation first, then tests; run tests only to confirm green (no "verify it fails" steps).

**Goal:** Make the candidate-level Conversation interactive: a new-comment form at the bottom of the candidate page and a collapsed "Reply…" affordance on each thread, wired through the full write path — routes, `CommentPolicy`, `CommentsController#create`, Turbo Stream append, and a small Stimulus reply-toggle controller. This is the plumbing Stages 5 and 8 reuse for pinned/line comments.

**Architecture:** A `comments` resource nested under the candidate with a single `create` action serving both roots and replies (a reply is just `parent_id` set). Stage 3 roots are always `scope: "candidate"` / `part: "whole"` (set server-side; the form sends only `body` + `parent_id` — Stage 5 swaps this default for `CommentAnchor.from_params`). **Replies inherit their parent's anchor** as a `Comment` model invariant (`before_validation`), so the reply plumbing built here already works unchanged for the anchored scopes of later stages. The controller lands in two increments: first redirect-only (full-page refresh, end-to-end testable), then Turbo Stream responses that append in place and reset the form. `CommentPolicy#create?` mirrors `CandidatePolicy#show?` — any member of the candidate's group; candidate state (`open`/`merged`/`rejected`) is deliberately not checked (comments double as post-decision archeology, like commenting on a closed PR).

## Global Constraints

- Tests use **RSpec** (`spec/`); run with `bundle exec rspec`. Not TDD — write tests after impl, run green.
- No DB changes in this stage — no migration, no `dev:setup` needed.
- Authorization keys off **group membership only** (`@user.group === candidate.project.group`); `User#role` is irrelevant to commenting. No candidate-state restriction on commenting.
- Comments are **immutable** in v1 — `only: [ :create ]`, no update/destroy anywhere.
- **Route order matters:** `resources :comments` must be declared **before** the `match "*"` test-server wildcard inside the candidates block, so a seeded API endpoint whose path is `/comments` can never shadow the comments route.
- Rails Omakase style: 2-space indent, double quotes, snake_case. Business rules (anchor inheritance) live in the model, not the controller.
- Views follow the White & Sky palette (`CLAUDE.md`): primary button `bg-sky-600 hover:bg-sky-700 text-white`, secondary `bg-white text-gray-700 border border-gray-300 hover:bg-gray-50`, input `border-gray-300 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-sky-500`. Lean ERB — no explanatory comments, no impossible-state guards.
- Commits: plain one-line messages, straight to `main`, no branch/PR, no `Co-Authored-By`. Only commit when the executing session is cleared to.

---

### Task 1: Reply anchor inheritance on the `Comment` model

**Files:**
- Modify: `app/models/comment.rb`
- Test: `spec/models/comment_spec.rb`

**Interfaces:**
- Consumes: existing `Comment` associations/validations, `CommentAnchor`.
- Produces: `Comment::ANCHOR_ATTRIBUTES` (frozen `%w[]` of the 8 anchor column names) and a `before_validation` that copies the parent's anchor columns onto any reply. Later tasks (and Stages 5/8) rely on this: a reply's form never sends anchor fields.

- [ ] **Step 1: Add the inheritance callback**

In `app/models/comment.rb`, add the constant and callback below the `has_many :replies` line:

```ruby
  ANCHOR_ATTRIBUTES = %w[scope part line endpoint_path endpoint_http_verb entity_name response_code anchor_snapshot].freeze

  before_validation :inherit_parent_anchor, if: :parent
```

and the private method at the bottom (below `anchor_valid`):

```ruby
  def inherit_parent_anchor
    assign_attributes(parent.slice(*ANCHOR_ATTRIBUTES))
  end
```

(`ActiveModel#slice` returns the named attributes as a hash; a reply therefore always carries its parent's exact anchor, even if the caller set something else.)

- [ ] **Step 2: Add model spec coverage**

Append to the top-level `describe Comment` block in `spec/models/comment_spec.rb` (reuses the file's existing `author` / `candidate` lets):

```ruby
  describe "anchor inheritance" do
    it "copies the parent's anchor onto a reply" do
      root = FactoryBot.create :comment, :endpoint_scope, candidate: candidate
      reply = FactoryBot.create :comment, candidate: candidate, parent: root
      expect(reply.scope).to eq("endpoint")
      expect(reply.endpoint_path).to eq("/users")
      expect(reply.endpoint_http_verb).to eq(0)
      expect(reply.anchor_key).to eq(root.anchor_key)
    end

    it "overrides anchor attributes supplied on the reply itself" do
      root = FactoryBot.create :comment, candidate: candidate
      reply = FactoryBot.create :comment, :entity_scope, candidate: candidate, parent: root
      expect(reply.scope).to eq("candidate")
      expect(reply.entity_name).to be_nil
    end
  end
```

- [ ] **Step 3: Run the specs**

Run: `bundle exec rspec spec/models/comment_spec.rb`
Expected: all green.

- [ ] **Step 4: Commit**

```bash
git add app/models/comment.rb spec/models/comment_spec.rb
git commit -m "Make replies inherit their parent comment's anchor"
```

---

### Task 2: Route + `CommentPolicy` + `CommentsController#create` (redirect-only)

**Files:**
- Modify: `config/routes.rb`
- Create: `app/policies/comment_policy.rb`
- Create: `app/controllers/comments_controller.rb`
- Test: `spec/requests/comments_requests_spec.rb`

**Interfaces:**
- Consumes: `Comment` (Task 1 inheritance), `Current.user`, Pundit's `authorize`, `sign_in` request helper.
- Produces:
  - `POST /projects/:project_name/candidates/:candidate_name/comments` → helper `project_candidate_comments_path(project_name, candidate_name)`.
  - `CommentPolicy#create?`.
  - `CommentsController#create` accepting `comment: { body:, parent_id: }`; sets `author` from session, defaults roots to `scope: "candidate"` / `part: "whole"`; redirects to the candidate page on both success and failure (Task 4 adds the Turbo Stream success format).

- [ ] **Step 1: Add the nested route**

In `config/routes.rb`, add `resources :comments` as the **first** line inside the candidates block, before the test-server wildcard:

```ruby
    resources :candidates, only: [ :new, :create, :show, :edit, :update ], param: :name do
      resources :comments, only: [ :create ]
      match "*", via: :all, to: "test_server#candidate", constraints: CandidateTestServerConstraint.new
      resource :merge, only: [ :create ]
      resource :rejection, only: [ :create ]
    end
```

- [ ] **Step 2: Write the policy**

Create `app/policies/comment_policy.rb`:

```ruby
class CommentPolicy < ApplicationPolicy
  def create?
    @user.group === @record.candidate.project.group
  end
end
```

- [ ] **Step 3: Write the controller**

Create `app/controllers/comments_controller.rb`:

```ruby
class CommentsController < ApplicationController
  def create
    @project = Project.find_by!(name: params[:project_name])
    @candidate = Candidate.find_by!(name: params[:candidate_name], project: @project)
    @comment = @candidate.comments.new(comment_params)
    @comment.author = Current.user
    @comment.assign_attributes(scope: "candidate", part: "whole") if @comment.parent_id.blank?
    authorize @comment

    if @comment.save
      redirect_to project_candidate_path(@project.name, @candidate.name)
    else
      redirect_to project_candidate_path(@project.name, @candidate.name), alert: "Comment could not be posted."
    end
  end

  private

  def comment_params
    params.require(:comment).permit(:body, :parent_id)
  end
end
```

Notes for the implementer:
- A forged `parent_id` from another candidate is caught by the model's `reply_on_parent_candidate` validation → falls into the failure branch. No extra controller check needed.
- `author_id` is not permitted, so it cannot be forged from the form.
- Replies get their anchor from Task 1's inheritance; the `parent_id.blank?` guard only defaults roots.

- [ ] **Step 4: Write the request spec**

Create `spec/requests/comments_requests_spec.rb`:

```ruby
require "rails_helper"

describe "Comments requests", type: :request do
  let(:group) { FactoryBot.create :group, name: "Test group" }
  let(:user) { FactoryBot.create :user, email_address: "test@example.com", password: "password", group: group }
  let(:project) { FactoryBot.create :project, name: "project", group: group }
  let(:candidate) { FactoryBot.create :candidate, project: project, name: "rc1" }

  let(:another_group) { FactoryBot.create :group, name: "Test group 2" }
  let(:another_user) { FactoryBot.create :user, email_address: "test2@example.com", password: "password", group: another_group }

  describe "#create" do
    it "creates a candidate-level root comment authored by the signed-in user" do
      sign_in(user)
      post project_candidate_comments_path(project.name, candidate.name),
           params: { comment: { body: "First!" } }

      comment = Comment.last
      expect(comment.body).to eq("First!")
      expect(comment.author).to eq(user)
      expect(comment.candidate).to eq(candidate)
      expect(comment.scope).to eq("candidate")
      expect(comment.part).to eq("whole")
      expect(comment.root?).to be true
      expect(response).to redirect_to(project_candidate_path(project.name, candidate.name))
    end

    it "creates a reply that inherits the root's anchor" do
      root = FactoryBot.create :comment, candidate: candidate
      sign_in(user)
      post project_candidate_comments_path(project.name, candidate.name),
           params: { comment: { body: "Agreed.", parent_id: root.id } }

      reply = Comment.last
      expect(reply.parent).to eq(root)
      expect(reply.anchor_key).to eq(root.anchor_key)
    end

    it "does not create a comment for a user outside the group" do
      sign_in(another_user)
      expect {
        post project_candidate_comments_path(project.name, candidate.name),
             params: { comment: { body: "Sneaky" } }
      }.not_to change(Comment, :count)
      expect(response).to redirect_to("/")
      expect(flash[:alert]).to eq("You are not authorized to perform this action.")
    end

    it "rejects a reply to a reply" do
      root = FactoryBot.create :comment, candidate: candidate
      reply = FactoryBot.create :comment, candidate: candidate, parent: root
      sign_in(user)
      expect {
        post project_candidate_comments_path(project.name, candidate.name),
             params: { comment: { body: "Too deep", parent_id: reply.id } }
      }.not_to change(Comment, :count)
      expect(flash[:alert]).to eq("Comment could not be posted.")
    end

    it "rejects a blank body" do
      sign_in(user)
      expect {
        post project_candidate_comments_path(project.name, candidate.name),
             params: { comment: { body: "" } }
      }.not_to change(Comment, :count)
      expect(flash[:alert]).to eq("Comment could not be posted.")
    end

    it "rejects a parent from another candidate" do
      other_candidate = FactoryBot.create :candidate, project: project, name: "rc2"
      foreign_root = FactoryBot.create :comment, candidate: other_candidate
      sign_in(user)
      expect {
        post project_candidate_comments_path(project.name, candidate.name),
             params: { comment: { body: "Crossed wires", parent_id: foreign_root.id } }
      }.not_to change(Comment, :count)
      expect(flash[:alert]).to eq("Comment could not be posted.")
    end

    it "ignores a client-supplied author_id" do
      forged = FactoryBot.create :user, email_address: "forged@example.com", group: group
      sign_in(user)
      post project_candidate_comments_path(project.name, candidate.name),
           params: { comment: { body: "Hi", author_id: forged.id } }
      expect(Comment.last.author).to eq(user)
    end
  end
end
```

- [ ] **Step 5: Run the request spec + full suite**

Run: `bundle exec rspec spec/requests/comments_requests_spec.rb`
Expected: all green.

Run: `bundle exec rspec`
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add config/routes.rb app/policies/comment_policy.rb app/controllers/comments_controller.rb spec/requests/comments_requests_spec.rb
git commit -m "Add CommentsController create with group-membership policy"
```

---

### Task 3: Comment + reply forms in the UI (full-page refresh)

**Files:**
- Create: `app/views/comments/_form.html.erb`
- Create: `app/views/comments/_reply.html.erb`
- Create: `app/views/comments/_reply_form.html.erb`
- Modify: `app/views/comments/_thread.html.erb`
- Modify: `app/views/candidates/show.html.erb` (Conversation section, lines 55–66)
- Create: `app/javascript/controllers/reply_controller.js`
- Test: `spec/requests/candidates_requests_spec.rb`

**Interfaces:**
- Consumes: `project_candidate_comments_path` (Task 2), `comments/_comment` partial, Stimulus via importmap (`pin_all_from app/javascript/controllers` auto-picks up the new controller).
- Produces:
  - `comments/_form` — locals `candidate:`, `parent:` (nil for a root form); posts `comment[body]` + `comment[parent_id]`.
  - `comments/_reply` — local `reply:`; one bordered reply row (also the unit Task 4's stream appends).
  - `comments/_reply_form` — local `parent:`; the collapsed "Reply…" trigger + hidden form (also the unit Task 4's stream re-renders to reset).
  - Stable DOM ids Task 4 targets: `candidate_comment_threads`, `no_comments_message`, `new_comment_form`, `dom_id(comment)`, `dom_id(comment, :replies)`, `dom_id(comment, :reply_form)`.
  - `reply` Stimulus controller with `show` / `cancel` actions and `trigger` / `form` targets.

- [ ] **Step 1: Write the shared comment form partial**

Create `app/views/comments/_form.html.erb`:

```erb
<%= form_with url: project_candidate_comments_path(candidate.project.name, candidate.name), scope: :comment do |form| %>
  <%= form.hidden_field :parent_id, value: parent&.id %>
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

- [ ] **Step 2: Write the reply-row and collapsed reply-form partials**

Create `app/views/comments/_reply.html.erb`:

```erb
<div class="border-t border-gray-100">
  <%= render "comments/comment", comment: reply %>
</div>
```

Create `app/views/comments/_reply_form.html.erb`:

```erb
<button type="button" data-reply-target="trigger" data-action="reply#show"
        class="w-full text-left text-sm text-gray-400 border border-gray-300 rounded-lg px-3 py-1.5 hover:bg-gray-50 cursor-text">Reply…</button>
<div data-reply-target="form" hidden>
  <%= render "comments/form", candidate: parent.candidate, parent: parent %>
</div>
```

- [ ] **Step 3: Restructure the thread partial**

Replace the full contents of `app/views/comments/_thread.html.erb` (the replies wrapper now always renders so Turbo can append into it; each reply row carries its own top border via `comments/_reply`):

```erb
<div id="<%= dom_id(comment) %>" class="bg-white border border-gray-200 rounded-lg">
  <%= render "comments/comment", comment: comment %>
  <div id="<%= dom_id(comment, :replies) %>" class="pl-6">
    <% comment.replies.sort_by(&:created_at).each do |reply| %>
      <%= render "comments/reply", reply: reply %>
    <% end %>
  </div>
  <div id="<%= dom_id(comment, :reply_form) %>" class="border-t border-gray-200 p-4" data-controller="reply">
    <%= render "comments/reply_form", parent: comment %>
  </div>
</div>
```

- [ ] **Step 4: Write the Stimulus reply controller**

Create `app/javascript/controllers/reply_controller.js`:

```js
import { Controller } from "@hotwired/stimulus"

// Collapses a thread's reply form behind a "Reply…" trigger.
export default class extends Controller {
  static targets = ["trigger", "form"]

  show() {
    this.triggerTarget.hidden = true
    this.formTarget.hidden = false
    this.formTarget.querySelector("textarea").focus()
  }

  cancel() {
    this.formTarget.hidden = true
    this.triggerTarget.hidden = false
  }
}
```

- [ ] **Step 5: Wire the Conversation section**

In `app/views/candidates/show.html.erb`, replace the whole `<section class="mt-10">…</section>` block with:

```erb
<section class="mt-10">
  <h2 class="text-xl font-semibold text-gray-900 mb-4">Conversation</h2>
  <div id="candidate_comment_threads" class="flex flex-col gap-6">
    <% @candidate_comment_threads.each do |thread| %>
      <%= render "comments/thread", comment: thread %>
    <% end %>
    <% if @candidate_comment_threads.empty? %>
      <p id="no_comments_message" class="text-sm text-gray-500">No comments yet.</p>
    <% end %>
  </div>
  <div id="new_comment_form" class="mt-6">
    <%= render "comments/form", candidate: @candidate, parent: nil %>
  </div>
</section>
```

- [ ] **Step 6: Add a render assertion to the candidates request spec**

In `spec/requests/candidates_requests_spec.rb`, inside the second `describe "#show"` block (the one with the Author-badge example), add:

```ruby
    it "renders the new-comment form and a reply trigger per thread" do
      candidate = FactoryBot.create :candidate, project: project, name: "rc9", author: author
      FactoryBot.create :comment, candidate: candidate, author: author, body: "Root comment"

      sign_in(user)
      get project_candidate_path(project.name, candidate.name)

      expect(response.body).to include("Leave a comment…")
      expect(response.body).to include("Reply…")
    end
```

- [ ] **Step 7: Run the specs**

Run: `bundle exec rspec spec/requests/candidates_requests_spec.rb spec/requests/comments_requests_spec.rb`
Expected: all green.

Run: `bundle exec rspec`
Expected: all green.

- [ ] **Step 8: Visual gate (user checkpoint)**

Run `bin/dev`, sign in, open `rc4` in `Superproject`. Confirm:
- A comment box ("Leave a comment…") sits below the threads; posting a root comment redirects back and the new thread appears (full page refresh is expected at this task).
- Each thread ends with a collapsed "Reply…" trigger; clicking it expands the reply form and focuses the textarea; Cancel collapses it back.
- Posting a reply nests it under the right root with the Author badge rules intact.
- The existing seeded threads look unchanged (reply indentation/borders).

**Stop here for the user to approve the visual result before committing.**

- [ ] **Step 9: Commit**

```bash
git add app/views/comments/_form.html.erb app/views/comments/_reply.html.erb app/views/comments/_reply_form.html.erb app/views/comments/_thread.html.erb app/views/candidates/show.html.erb app/javascript/controllers/reply_controller.js spec/requests/candidates_requests_spec.rb
git commit -m "Add comment and reply forms to the candidate Conversation"
```

---

### Task 4: Turbo Stream responses (append in place, reset forms)

**Files:**
- Modify: `app/controllers/comments_controller.rb`
- Create: `app/views/comments/create.turbo_stream.erb`
- Test: `spec/requests/comments_requests_spec.rb`

**Interfaces:**
- Consumes: DOM ids and partials from Task 3 (`candidate_comment_threads`, `no_comments_message`, `new_comment_form`, `dom_id(parent, :replies)`, `dom_id(parent, :reply_form)`; `comments/_thread`, `_reply`, `_reply_form`, `_form`).
- Produces: `create` answers `text/vnd.turbo-stream.html` — new root: remove empty-state, append thread, re-render the root form blank; reply: append the reply row, re-render the reply area collapsed. HTML fallback keeps the Task 2 redirect. Failure keeps the redirect + alert for both formats.

- [ ] **Step 1: Add the turbo_stream format to the controller**

In `app/controllers/comments_controller.rb`, replace the success branch:

```ruby
    if @comment.save
      redirect_to project_candidate_path(@project.name, @candidate.name)
    else
```

with:

```ruby
    if @comment.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to project_candidate_path(@project.name, @candidate.name) }
      end
    else
```

- [ ] **Step 2: Write the stream template**

Create `app/views/comments/create.turbo_stream.erb`:

```erb
<% if @comment.reply? %>
  <%= turbo_stream.append dom_id(@comment.parent, :replies) do %>
    <%= render "comments/reply", reply: @comment %>
  <% end %>
  <%= turbo_stream.update dom_id(@comment.parent, :reply_form) do %>
    <%= render "comments/reply_form", parent: @comment.parent %>
  <% end %>
<% else %>
  <%= turbo_stream.remove "no_comments_message" %>
  <%= turbo_stream.append "candidate_comment_threads" do %>
    <%= render "comments/thread", comment: @comment %>
  <% end %>
  <%= turbo_stream.update "new_comment_form" do %>
    <%= render "comments/form", candidate: @candidate, parent: nil %>
  <% end %>
<% end %>
```

(`turbo_stream.update` on the reply-form wrapper collapses it back to the "Reply…" trigger — the `data-controller="reply"` attribute lives on the wrapper and survives the update; `turbo_stream.remove` of an absent `no_comments_message` is a no-op.)

- [ ] **Step 3: Add stream request specs**

Append inside `describe "#create"` in `spec/requests/comments_requests_spec.rb`:

```ruby
    it "answers a turbo stream that appends the new thread and resets the form" do
      sign_in(user)
      post project_candidate_comments_path(project.name, candidate.name),
           params: { comment: { body: "First!" } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('action="append" target="candidate_comment_threads"')
      expect(response.body).to include('action="remove" target="no_comments_message"')
      expect(response.body).to include('action="update" target="new_comment_form"')
      expect(response.body).to include("First!")
    end

    it "answers a turbo stream that appends a reply into its thread" do
      root = FactoryBot.create :comment, candidate: candidate
      sign_in(user)
      post project_candidate_comments_path(project.name, candidate.name),
           params: { comment: { body: "Agreed.", parent_id: root.id } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.body).to include(%(action="append" target="replies_comment_#{root.id}"))
      expect(response.body).to include(%(action="update" target="reply_form_comment_#{root.id}"))
      expect(response.body).to include("Agreed.")
    end
```

- [ ] **Step 4: Run the request spec + full suite**

Run: `bundle exec rspec spec/requests/comments_requests_spec.rb`
Expected: all green (the Task 2 redirect examples still pass — the HTML format keeps redirecting).

Run: `bundle exec rspec`
Expected: all green.

- [ ] **Step 5: Visual gate (user checkpoint)**

With `bin/dev` still running, on the `rc4` page confirm — **no full page reload on any of these**:
- Posting a root comment appends the thread at the bottom of the list and clears the comment box.
- On a candidate with no comments (create a fresh one if needed), "No comments yet." disappears when the first comment is posted.
- Posting a reply appends it under the right root and collapses the reply form back to the "Reply…" trigger.
- The appended thread/reply immediately has a working "Reply…" trigger (Stimulus connected on streamed content).

**Stop here for the user to approve before committing.**

- [ ] **Step 6: Commit**

```bash
git add app/controllers/comments_controller.rb app/views/comments/create.turbo_stream.erb spec/requests/comments_requests_spec.rb
git commit -m "Append comments and replies in place via Turbo Streams"
```

---

## Self-Review

**Spec coverage (Stage 3 row: "Candidate-level interactive: create + reply — full controller / policy / Turbo / Stimulus plumbing"):**
- `CommentsController` nested under candidate, `create` for root + reply, Turbo Stream responses → Tasks 2 + 4. ✅
- `CommentPolicy` create/reply = any member of the candidate's group → Task 2. ✅
- Conversation section: new-comment form + per-thread reply forms → Task 3. ✅
- Stimulus comment/reply controllers → Task 3 (`reply_controller.js`; the root form needs no JS — Turbo handles submit/reset). ✅
- "Replies inherit the parent's anchor" (design §comments table) → Task 1, as a model invariant reused by Stages 5/8. ✅
- Request specs: policy enforcement, create root + reply, forged `author_id`/`parent_id`, one-level enforcement, turbo stream bodies → Tasks 2–4. ✅
- Out of scope, correctly deferred: anchored "＋ comment" affordances (Stage 5), `CommentAnchor.from_params` (Stages 4/5), line selection (7/8), resolve (9).

**Placeholder scan:** none — every code step is complete and copy-pasteable.

**Type consistency:** form posts `comment[body]` / `comment[parent_id]`; controller permits exactly those. DOM ids produced in Task 3 (`candidate_comment_threads`, `no_comments_message`, `new_comment_form`, `replies_comment_<id>`, `reply_form_comment_<id>`) match Task 4's stream targets and specs (Rails `dom_id(record, prefix)` renders `prefix_comment_<id>`). Partial locals are `comment:` (`_comment`, `_thread`), `reply:` (`_reply`), `parent:` (`_reply_form`), `candidate:`+`parent:` (`_form`) throughout. `Comment::ANCHOR_ATTRIBUTES` strings match the `comments` schema columns.
