# Candidate Commenting — Stage 2 (Comment model + candidate-level Conversation) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **This plan is deliberately not TDD** — write implementation first, then tests; run tests only to confirm green (no "verify it fails" steps).

**Goal:** Introduce the `Comment` model (full anchor schema + validations) and render the candidate-level "Conversation" section on the candidate page — root comments, one level of flat replies, and an "Author" badge on the candidate author's comments — seeded from dev fixtures. Render-only: no create/reply forms yet (Stage 3).

**Architecture:** A new `comments` table hangs comments off the candidate (so they survive merge/reject). The full anchor schema (scope / endpoint / entity / response / part / line / snapshot) ships now, but Stage 2 only exercises `scope: candidate` / `part: whole`. A **`CommentAnchor` value object** owns the scope×part matrix as a single declarative table, the anchor validation, and the in-memory grouping key — so the logical-identity rules read at a glance and live out of the ActiveRecord model (the design's intent). `CommentAnchor` is introduced minimally here (`key`, `errors`); its Version-dependent methods (`from_params`, `resolve_against`, `to_columns`, `label`) arrive in Stage 4. The `Comment` model handles threading + attribution and **delegates all anchor logic** to `CommentAnchor`. The candidate page's controller loads the candidate's comments once and the view renders the candidate-scope root threads through reusable `comments/_thread` + `comments/_comment` partials. The controller/policy write path and resolvability are out of scope (Stages 3, 9).

## Global Constraints

- Tests use **RSpec** (`spec/`); run with `bundle exec rspec`. Not TDD — no failing-first steps; write tests after impl and run green.
- **`comments` is a brand-new table → a new migration file is correct.** The project's edit-migrations-in-place rule is about *altering existing tables* (as Stage 1 did to `candidates`); a new table gets its own migration. Still reset with `bin/rails dev:setup` (runs `db:migrate:reset`, reloads `test/fixtures/*`, regenerates `db/schema.rb`) — never `db:migrate`. No schema drift.
- **Stage 2 excludes the resolve columns** (`resolved_at`, `resolved_by_id`) — they arrive in Stage 9. Everything else in the design's `comments` schema ships now.
- All fixtures live in **`test/fixtures/`** and are the running dev app's seed data, loaded by `bin/rails dev:setup`. RSpec's own fixtures point at `spec/fixtures` and are unused here — model/request specs build data with **FactoryBot**.
- Rails Omakase style: 2-space indent, double quotes, snake_case methods. Business logic (threading, anchor rules, badge predicate) lives in the model layer, not the view.
- Views follow the White & Sky palette (`CLAUDE.md`): panels `bg-white border-gray-200`, secondary text `text-gray-500`, body text `text-gray-700`. Lean ERB — no explanatory comments, no guards for impossible states.
- Commits: plain one-line messages, straight to `main`, no branch/PR, no `Co-Authored-By` (project git workflow). Only commit when the executing session is cleared to.

---

### Task 1: `CommentAnchor` value object (matrix + key + validation)

**Files:**
- Create: `app/models/comment_anchor.rb`
- Create: `spec/models/comment_anchor_spec.rb`

**Interfaces:**
- Consumes: nothing (plain Ruby object; uses ActiveSupport `blank?`/`present?`).
- Produces:
  - `CommentAnchor::RULES` — the single source-of-truth matrix (`scope → { parts:, identity: }`).
  - `CommentAnchor::IDENTITY_COLUMNS`, `CommentAnchor::LINE_PARTS`.
  - `CommentAnchor.new(scope:, part:, line:, endpoint_path:, endpoint_http_verb:, entity_name:, response_code:)`.
  - `#key` → `[scope, endpoint_path, endpoint_http_verb, entity_name, response_code, part, line]`.
  - `#errors` → `[]` when valid, else `[[column_symbol, message_string], …]`.

- [ ] **Step 1: Write the value object**

Create `app/models/comment_anchor.rb`. The matrix is one row per scope; `forbidden` identity columns are **derived** (`IDENTITY_COLUMNS − rule[:identity]`), so required/forbidden can never drift out of sync:

```ruby
class CommentAnchor
  # One row per scope: which parts are legal, and which identity columns pin it down.
  RULES = {
    "candidate" => { parts: %w[whole],             identity: %i[] },
    "endpoint"  => { parts: %w[whole note],        identity: %i[endpoint_path endpoint_http_verb] },
    "entity"    => { parts: %w[whole root],        identity: %i[entity_name] },
    "response"  => { parts: %w[whole note output], identity: %i[endpoint_path endpoint_http_verb response_code] }
  }.freeze

  IDENTITY_COLUMNS = %i[endpoint_path endpoint_http_verb entity_name response_code].freeze
  LINE_PARTS = %w[note output root].freeze

  attr_reader :scope, :part, :line,
              :endpoint_path, :endpoint_http_verb, :entity_name, :response_code

  def initialize(scope:, part:, line: nil,
                 endpoint_path: nil, endpoint_http_verb: nil,
                 entity_name: nil, response_code: nil)
    @scope = scope
    @part = part
    @line = line
    @endpoint_path = endpoint_path
    @endpoint_http_verb = endpoint_http_verb
    @entity_name = entity_name
    @response_code = response_code
  end

  def key
    [ scope, endpoint_path, endpoint_http_verb, entity_name, response_code, part, line ]
  end

  def errors
    rule = RULES[scope]
    return [ [ :scope, "is not a valid scope" ] ] unless rule

    result = []
    result << [ :part, "is not valid for scope #{scope}" ] unless rule[:parts].include?(part)

    rule[:identity].each do |col|
      result << [ col, "is required for scope #{scope}" ] if public_send(col).blank?
    end
    (IDENTITY_COLUMNS - rule[:identity]).each do |col|
      result << [ col, "must be blank for scope #{scope}" ] if public_send(col).present?
    end

    result << [ :line, "requires a text part" ] if line.present? && !LINE_PARTS.include?(part)
    result
  end
end
```

Note: `endpoint_http_verb` is the integer enum value (`0 = GET`); `0.blank?` is `false`, so a `GET` anchor correctly reads as present, and `0.present?` correctly reads as forbidden-when-it-should-be-nil.

- [ ] **Step 2: Write the value-object spec**

Create `spec/models/comment_anchor_spec.rb` — this is where the exhaustive matrix cases live:

```ruby
require "rails_helper"

describe CommentAnchor do
  def anchor(**attrs)
    CommentAnchor.new(**{ scope: "candidate", part: "whole" }.merge(attrs))
  end

  describe "#key" do
    it "returns the logical-identity tuple in column order" do
      a = anchor(scope: "response", part: "output", line: 7,
                 endpoint_path: "/users", endpoint_http_verb: 0, response_code: "200")
      expect(a.key).to eq([ "response", "/users", 0, nil, "200", "output", 7 ])
    end
  end

  describe "#errors" do
    it "is empty for a valid candidate/whole anchor" do
      expect(anchor.errors).to eq([])
    end

    it "flags an unknown scope" do
      expect(anchor(scope: "nope").errors).to eq([ [ :scope, "is not a valid scope" ] ])
    end

    it "flags a part that is not legal for the scope" do
      expect(anchor(scope: "candidate", part: "note").errors).to include([ :part, a_string_including("not valid") ])
    end

    it "requires the scope's identity columns" do
      a = anchor(scope: "endpoint", part: "whole", endpoint_path: nil, endpoint_http_verb: 0)
      expect(a.errors).to include([ :endpoint_path, a_string_including("required") ])
    end

    it "treats GET (verb 0) as present, not missing" do
      a = anchor(scope: "endpoint", part: "whole", endpoint_path: "/users", endpoint_http_verb: 0)
      expect(a.errors).to eq([])
    end

    it "forbids identity columns from other scopes" do
      a = anchor(scope: "candidate", part: "whole", entity_name: "User")
      expect(a.errors).to include([ :entity_name, a_string_including("must be blank") ])
    end

    it "requires response_code for a response anchor" do
      a = anchor(scope: "response", part: "whole",
                 endpoint_path: "/users", endpoint_http_verb: 0, response_code: nil)
      expect(a.errors).to include([ :response_code, a_string_including("required") ])
    end

    it "allows a line only on a text part" do
      valid = anchor(scope: "response", part: "output", line: 3,
                     endpoint_path: "/users", endpoint_http_verb: 0, response_code: "200")
      invalid = anchor(scope: "response", part: "whole", line: 3,
                       endpoint_path: "/users", endpoint_http_verb: 0, response_code: "200")
      expect(valid.errors).to eq([])
      expect(invalid.errors).to include([ :line, a_string_including("text part") ])
    end
  end
end
```

- [ ] **Step 3: Run the spec**

Run: `bundle exec rspec spec/models/comment_anchor_spec.rb`
Expected: all green.

- [ ] **Step 4: Commit**

```bash
git add app/models/comment_anchor.rb spec/models/comment_anchor_spec.rb
git commit -m "Add CommentAnchor value object with the scope/part matrix"
```

---

### Task 2: `Comment` model + migration + factory

**Files:**
- Create: `db/migrate/20260703000001_create_comments.rb`
- Create: `app/models/comment.rb`
- Modify: `app/models/candidate.rb`
- Create: `spec/factories/comments.rb`
- Create: `spec/models/comment_spec.rb`

**Interfaces:**
- Consumes: `CommentAnchor` (Task 1); `Candidate` (Stage 1 `author` association); `User`.
- Produces:
  - DB table `comments` with columns `candidate_id` (not null), `author_id` (not null), `parent_id` (nullable), `body` (text, not null), `scope` (string, not null), `endpoint_path`, `endpoint_http_verb` (integer), `entity_name`, `response_code`, `part` (string, not null), `line` (integer), `anchor_snapshot` (text); indexes on `candidate_id`, `author_id`, `parent_id`.
  - `Comment` with `belongs_to :candidate`, `belongs_to :author` (User), `belongs_to :parent` (Comment, optional), `has_many :replies`.
  - `Comment#root?`, `#reply?`, `#by_candidate_author?`, `#anchor` (→ `CommentAnchor`), `#anchor_key` (→ `anchor.key`).
  - `Candidate#comments` (`has_many`).
  - `:comment` factory (default candidate-scope/whole) with traits `:endpoint_scope`, `:entity_scope`, `:response_scope`, `:reply`.

- [ ] **Step 1: Write the migration**

Create `db/migrate/20260703000001_create_comments.rb`:

```ruby
class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments do |t|
      t.references :candidate, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.references :parent, null: true, foreign_key: { to_table: :comments }
      t.text :body, null: false

      t.string :scope, null: false
      t.string :endpoint_path
      t.integer :endpoint_http_verb
      t.string :entity_name
      t.string :response_code
      t.string :part, null: false
      t.integer :line
      t.text :anchor_snapshot

      t.timestamps
    end
  end
end
```

- [ ] **Step 2: Write the `Comment` model**

Create `app/models/comment.rb`. Threading + attribution live here; all anchor logic is delegated to `CommentAnchor`:

```ruby
class Comment < ApplicationRecord
  belongs_to :candidate
  belongs_to :author, class_name: "User"
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy

  validates :body, presence: true
  validate :parent_must_be_root
  validate :anchor_valid

  def root?
    parent_id.nil?
  end

  def reply?
    !root?
  end

  def by_candidate_author?
    author_id == candidate.author_id
  end

  def anchor
    CommentAnchor.new(
      scope: scope, part: part, line: line,
      endpoint_path: endpoint_path, endpoint_http_verb: endpoint_http_verb,
      entity_name: entity_name, response_code: response_code
    )
  end

  def anchor_key
    anchor.key
  end

  private

  def parent_must_be_root
    return if parent.nil?
    errors.add(:parent, "must be a root comment") unless parent.root?
  end

  def anchor_valid
    anchor.errors.each { |column, message| errors.add(column, message) }
  end
end
```

- [ ] **Step 3: Add `has_many :comments` to `Candidate`**

In `app/models/candidate.rb`, add below `has_many :versions`:

```ruby
  has_many :comments
```

- [ ] **Step 4: Write the factory**

Create `spec/factories/comments.rb`. `scope` is declared via `add_attribute` (it collides with FactoryBot/ActiveRecord DSL names):

```ruby
FactoryBot.define do
  factory :comment do
    association :candidate
    association :author, factory: :user
    body { "Looks good to me." }
    add_attribute(:scope) { "candidate" }
    part { "whole" }

    trait :endpoint_scope do
      add_attribute(:scope) { "endpoint" }
      endpoint_path { "/users" }
      endpoint_http_verb { 0 }
    end

    trait :entity_scope do
      add_attribute(:scope) { "entity" }
      entity_name { "User" }
    end

    trait :response_scope do
      add_attribute(:scope) { "response" }
      endpoint_path { "/users" }
      endpoint_http_verb { 0 }
      response_code { "200" }
    end

    trait :reply do
      association :parent, factory: :comment
    end
  end
end
```

- [ ] **Step 5: Reset the DB and reload fixtures**

Run: `bin/rails dev:setup`
Expected: ends with `✅ Dev setup complete!`; `db/schema.rb` gains a `comments` table with the columns and indexes from Step 1. (No `comments.yml` yet — that's Task 3.)

- [ ] **Step 6: Write the model spec**

The exhaustive matrix cases already live in `comment_anchor_spec.rb`; this spec covers threading, attribution, and that the model *delegates* anchor validity. Create `spec/models/comment_spec.rb`:

```ruby
require "rails_helper"

describe Comment do
  let(:author) { FactoryBot.create :user }
  let(:candidate) { FactoryBot.create :candidate, author: author }

  it "builds a valid candidate-scope root from the factory" do
    expect(FactoryBot.build(:comment)).to be_valid
  end

  it "requires a body" do
    expect(FactoryBot.build(:comment, body: "")).not_to be_valid
  end

  it "surfaces CommentAnchor errors on the record" do
    comment = FactoryBot.build(:comment, scope: "candidate", part: "whole", entity_name: "User")
    expect(comment).not_to be_valid
    expect(comment.errors[:entity_name]).to be_present
  end

  describe "one-level threading" do
    it "allows a reply to a root" do
      root = FactoryBot.create :comment, candidate: candidate
      expect(FactoryBot.build(:comment, candidate: candidate, parent: root)).to be_valid
    end

    it "rejects a reply to a reply" do
      root = FactoryBot.create :comment, candidate: candidate
      reply = FactoryBot.create :comment, candidate: candidate, parent: root
      expect(FactoryBot.build(:comment, candidate: candidate, parent: reply)).not_to be_valid
    end
  end

  describe "#root? / #reply?" do
    it "is a root when parent is nil" do
      comment = FactoryBot.build :comment
      expect(comment.root?).to be true
      expect(comment.reply?).to be false
    end

    it "is a reply when parent is set" do
      root = FactoryBot.create :comment, candidate: candidate
      reply = FactoryBot.build :comment, candidate: candidate, parent: root
      expect(reply.reply?).to be true
    end
  end

  describe "#by_candidate_author?" do
    it "is true when the comment author is the candidate author" do
      expect(FactoryBot.build(:comment, candidate: candidate, author: author).by_candidate_author?).to be true
    end

    it "is false for anyone else" do
      other = FactoryBot.create :user
      expect(FactoryBot.build(:comment, candidate: candidate, author: other).by_candidate_author?).to be false
    end
  end

  describe "#anchor_key" do
    it "delegates to the anchor's key" do
      comment = FactoryBot.build :comment, :response_scope, part: "output", line: 7
      expect(comment.anchor_key).to eq([ "response", "/users", 0, nil, "200", "output", 7 ])
    end
  end
end
```

- [ ] **Step 7: Run the model spec + factory lint + full suite**

Run: `bundle exec rspec spec/models/comment_spec.rb spec/models/comment_anchor_spec.rb spec/models/factories_spec.rb`
Expected: all green (factory lint proves the default `:comment` builds valid).

Run: `bundle exec rspec`
Expected: all green (schema-change guard).

- [ ] **Step 8: Commit**

```bash
git add db/migrate/20260703000001_create_comments.rb db/schema.rb app/models/comment.rb app/models/candidate.rb spec/factories/comments.rb spec/models/comment_spec.rb
git commit -m "Add Comment model delegating anchor rules to CommentAnchor"
```

---

### Task 3: Candidate-level comment dev fixtures

**Files:**
- Create: `test/fixtures/comments.yml`

**Interfaces:**
- Consumes: `candidates.yml` (`candidate4`, authored by `two`), `users.yml` (`one`, `two`).
- Produces: seeded candidate-scope threads on `candidate4` in the running dev app, so the Conversation section (Task 4) is examinable — including a reply and a mix of author / non-author comments to show the "Author" badge.

- [ ] **Step 1: Write the fixtures**

`candidate4` (rc4) is authored by `two`, so comments by `two` carry the Author badge; `one` is a plain reviewer. Replies set the same `scope`/`part` as their root (both columns are `NOT NULL`; fixtures bypass model validation but the DB still requires them). Create `test/fixtures/comments.yml`:

```yaml
c4_flag_root:
  candidate: candidate4
  author: one
  body: "Should we gate this behind a flag before merging?"
  scope: candidate
  part: whole
  created_at: 2025-04-01 10:00:00

c4_flag_reply:
  candidate: candidate4
  author: two
  parent: c4_flag_root
  body: "Good call — I'll gate it and push an update."
  scope: candidate
  part: whole
  created_at: 2025-04-01 11:15:00

c4_rename_root:
  candidate: candidate4
  author: two
  body: "Renamed the endpoint for consistency with the others in this version."
  scope: candidate
  part: whole
  created_at: 2025-04-02 09:30:00
```

- [ ] **Step 2: Reload fixtures**

Run: `bin/rails dev:setup`
Expected: ends with `✅ Dev setup complete!`; fixture loading succeeds (the `candidate:`, `author:`, and `parent:` labels resolve).

- [ ] **Step 3: Commit**

```bash
git add test/fixtures/comments.yml
git commit -m "Seed candidate-level comment fixtures on rc4"
```

---

### Task 4: Render the candidate-level Conversation section

**Files:**
- Modify: `app/controllers/candidates_controller.rb` (`#show`)
- Create: `app/views/comments/_thread.html.erb`
- Create: `app/views/comments/_comment.html.erb`
- Modify: `app/views/candidates/show.html.erb`
- Test: `spec/requests/candidates_requests_spec.rb`

**Interfaces:**
- Consumes: `Candidate#comments`, `Comment#root?`, `Comment#replies`, `Comment#by_candidate_author?`, `Comment#author`.
- Produces: `@candidate_comment_threads` on `candidates#show`; a "Conversation" section rendering candidate-scope root threads with the Author badge. Reusable `comments/_thread` (root + flat replies) and `comments/_comment` (one comment card) partials that Stages 3–8 extend.

- [ ] **Step 1: Load the candidate's comment threads in the controller**

In `app/controllers/candidates_controller.rb`, at the end of the `#show` action (after the `@categorized_entities` line), add:

```ruby
    @candidate_comment_threads = @candidate.comments
      .includes(:author, replies: :author)
      .select { |comment| comment.root? && comment.scope == "candidate" }
      .sort_by(&:created_at)
```

- [ ] **Step 2: Write the single-comment partial**

Create `app/views/comments/_comment.html.erb`:

```erb
<div class="p-4">
  <div class="flex items-center gap-2 mb-1">
    <span class="text-sm font-semibold text-gray-900"><%= comment.author.email_address %></span>
    <% if comment.by_candidate_author? %>
      <span class="bg-sky-50 text-sky-700 border border-sky-200 text-xs font-semibold px-2 py-0.5 rounded-full">Author</span>
    <% end %>
    <span class="text-xs text-gray-500"><%= comment.created_at.strftime("%Y-%m-%d %H:%M") %></span>
  </div>
  <div class="text-sm text-gray-700 whitespace-pre-wrap"><%= comment.body %></div>
</div>
```

- [ ] **Step 3: Write the thread partial**

Create `app/views/comments/_thread.html.erb`:

```erb
<div class="bg-white border border-gray-200 rounded-lg">
  <%= render "comments/comment", comment: comment %>
  <% if comment.replies.any? %>
    <div class="border-t border-gray-200 pl-6 divide-y divide-gray-100">
      <% comment.replies.sort_by(&:created_at).each do |reply| %>
        <%= render "comments/comment", comment: reply %>
      <% end %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 4: Add the Conversation section to the candidate page**

In `app/views/candidates/show.html.erb`, after the closing `<% end %>` of the `render "versions/endpoints_and_entities"` block (the final line), append:

```erb
<section class="mt-10">
  <h2 class="text-xl font-semibold text-gray-900 mb-4">Conversation</h2>
  <% if @candidate_comment_threads.any? %>
    <div class="flex flex-col gap-6">
      <% @candidate_comment_threads.each do |thread| %>
        <%= render "comments/thread", comment: thread %>
      <% end %>
    </div>
  <% else %>
    <p class="text-sm text-gray-500">No comments yet.</p>
  <% end %>
</section>
```

- [ ] **Step 5: Write the request spec**

Add to `spec/requests/candidates_requests_spec.rb` a new `describe "#show"` block (reuses the file's existing `group`, `user`, `project`, `author`, and `sign_in`):

```ruby
  describe "#show" do
    it "renders candidate-level comments with an Author badge for the candidate author" do
      candidate = FactoryBot.create :candidate, project: project, name: "rc9", author: author
      FactoryBot.create :comment, candidate: candidate, author: author, body: "Comment by the candidate author"
      FactoryBot.create :comment, candidate: candidate, author: user, body: "Comment by a reviewer"

      sign_in(user)
      get project_candidate_path(project.name, candidate.name)

      expect(response.status).to eq(200)
      expect(response.body).to include("Conversation")
      expect(response.body).to include("Comment by the candidate author")
      expect(response.body).to include("Comment by a reviewer")
      expect(response.body).to include("Author")
    end
  end
```

- [ ] **Step 6: Run the request spec + full suite**

Run: `bundle exec rspec spec/requests/candidates_requests_spec.rb`
Expected: green, including the new `#show` example.

Run: `bundle exec rspec`
Expected: all green.

- [ ] **Step 7: Visual gate (user checkpoint)**

Run `bin/dev`, sign in, and open `candidate4` (rc4) in project `Superproject`. Confirm at the bottom of the page:
- A "Conversation" heading with two root threads.
- The "gate this behind a flag" thread has a nested reply from `two@example.com`, and that reply shows the **Author** badge (rc4's author is `two`); the root by `one@example.com` does not.
- The "Renamed the endpoint" root by `two@example.com` shows the Author badge.

**Stop here for the user to approve the visual result before committing.**

- [ ] **Step 8: Commit**

```bash
git add app/controllers/candidates_controller.rb app/views/comments/_thread.html.erb app/views/comments/_comment.html.erb app/views/candidates/show.html.erb spec/requests/candidates_requests_spec.rb
git commit -m "Render candidate-level Conversation with Author badge"
```

---

## Self-Review

**Spec coverage (Stage 2 rows of the design):**
- `comments` table + full anchor schema (minus resolve cols) → Task 2, Step 1. ✅
- Scope×part matrix + `anchor_key`, as a legible single-table value object out of the AR model → Task 1 (`CommentAnchor`). ✅ (Its Version-dependent methods — `from_params`, `resolve_against`, `to_columns`, `label` — remain deferred to Stage 4, per the staging table.)
- `Comment` associations, one-level threading validation, delegated anchor validity, `root?`/`reply?`/`by_candidate_author?`/`anchor_key` → Task 2, Steps 2 + 6. ✅
- FactoryBot `:comment` with per-scope traits → Task 2, Step 4. ✅
- `comments.yml` dev fixtures loaded by `dev:setup` → Task 3. ✅
- Candidate-level Conversation rendered with Author badge (render-only, no forms) → Task 4. ✅
- Specs: matrix (`comment_anchor_spec`), threading/attribution/delegation (`comment_spec`), render (`candidates_requests_spec`). ✅
- Resolve columns/behavior, controller write path, policy, Stimulus/Turbo → correctly **out of scope** (Stages 3, 9).

**Placeholder scan:** none — every code/step is concrete.

**Type consistency:** `scope`/`part` string values, `endpoint_http_verb` integer `0`, and the tuple order `[scope, endpoint_path, endpoint_http_verb, entity_name, response_code, part, line]` are identical across `CommentAnchor#key`, `Comment#anchor_key`, factory, fixtures, and specs. `CommentAnchor#errors` returns `[[Symbol, String], …]`, consumed by `Comment#anchor_valid` as `|column, message|`. Partial local is `comment:` throughout.
