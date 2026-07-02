# Candidate Attribution (Commenting — Stage 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **This plan is deliberately not TDD** — write implementation first, then tests; run tests only to confirm green (no "verify it fails" steps).

**Goal:** Record who proposed a candidate and who merged/rejected it (and when), and show "Proposed by X · Merged/Rejected by Y" on the candidate and version pages.

**Architecture:** Add three nullable columns to `candidates` — `author_id` (set in `Candidate::Create`), and a shared `decided_by_id` + `decided_at` (set in both `Candidate::Merge` and `Candidate::Reject`; the verb is derived from `aasm_state`). A `Candidate#attribution_parts` model method builds the display strings, rendered on two pages. This is the prerequisite for the later "Author badge" on comments (Stage 2).

## Global Constraints

- Tests use **RSpec** (`spec/`); run with `bundle exec rspec`. Not TDD — no failing-first steps.
- **DB changes: edit the existing migration in place, then run `bin/rails dev:setup`** (does `db:migrate:reset` + reloads fixtures + regenerates `db/schema.rb`). Do **not** add a new migration file. (Project workflow.)
- All three new columns are **nullable** (an `open` candidate has null `decided_by`/`decided_at`). Fixtures are updated to give the existing merged candidates realistic attribution.
- **No model specs** in this stage — coverage comes from the service specs and request specs.
- Rails Omakase style: 2-space indent, double quotes, snake_case methods. Business logic lives in the model, not the view.
- Views follow the White & Sky palette (`CLAUDE.md`): secondary text is `text-gray-500`.
- No comment code in this stage — attribution only.

---

### Task 1: Add attribution columns, associations, and fixtures

**Files:**
- Modify: `db/migrate/20250723162601_create_candidates.rb`
- Modify: `app/models/candidate.rb`
- Modify: `test/fixtures/candidates.yml`

**Interfaces:**
- Produces: DB columns `candidates.author_id`, `candidates.decided_by_id`, `candidates.decided_at`; `Candidate#author` / `#author=`, `Candidate#decided_by` / `#decided_by=`, `Candidate#decided_at` (all may be `nil`).

- [ ] **Step 1: Edit the migration in place**

In `db/migrate/20250723162601_create_candidates.rb`, add three lines inside the `create_table :candidates` block, after the `base_version` reference:

```ruby
      t.references :base_version, null: true, foreign_key: { to_table: :versions }
      t.references :author, null: true, foreign_key: { to_table: :users }
      t.references :decided_by, null: true, foreign_key: { to_table: :users }
      t.datetime :decided_at, null: true
```

- [ ] **Step 2: Add the associations**

In `app/models/candidate.rb`, add below the existing `belongs_to :base_version …` line (this must exist before fixtures load, so the `author:` / `decided_by:` labels in the fixture resolve):

```ruby
  belongs_to :author, class_name: "User", optional: true
  belongs_to :decided_by, class_name: "User", optional: true
```

- [ ] **Step 3: Give the fixture candidates attribution**

The existing fixture candidates (`candidate1..4`) are all `merged` and belong to `project1` (group `g1`), so attribute them to `g1` users — `two` proposes, `one` decides. Replace `test/fixtures/candidates.yml` with:

```yaml
candidate1:
  name: "rc1"
  project: project1
  order: 1
  aasm_state: "merged"
  author: two
  decided_by: one
  decided_at: 2025-01-10 09:00:00
candidate2:
  name: "rc2"
  project: project1
  order: 2
  aasm_state: "merged"
  author: two
  decided_by: one
  decided_at: 2025-02-14 11:30:00
candidate3:
  name: "rc3"
  project: project1
  order: 3
  aasm_state: "merged"
  author: two
  decided_by: one
  decided_at: 2025-03-20 15:45:00
candidate4:
  name: "rc4"
  project: project1
  order: 4
  aasm_state: "merged"
  author: two
  decided_by: one
  decided_at: 2025-04-05 08:15:00
```

- [ ] **Step 4: Reset the DB and reload fixtures**

Run: `bin/rails dev:setup`
Expected: ends with `✅ Dev setup complete!`; `db/schema.rb` now shows `author_id`, `decided_by_id`, and `decided_at` on `candidates`, and fixture loading succeeds (the `author:`/`decided_by:` labels resolve).

- [ ] **Step 5: Full suite (schema-change guard)**

Run: `bundle exec rspec`
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add db/migrate/20250723162601_create_candidates.rb db/schema.rb app/models/candidate.rb test/fixtures/candidates.yml
git commit -m "Add author/decided_by/decided_at attribution columns to candidates"
```

---

### Task 2: Capture the author in `Candidate::Create`

**Files:**
- Modify: `app/services/candidate/create.rb`
- Test: `spec/services/create_candidate_spec.rb`, `spec/requests/candidates_requests_spec.rb`

**Interfaces:**
- Consumes: `Candidate#author=` (Task 1); `Current.user` (set by `Authentication` concern in controllers).
- Produces: `Candidate::Create.new(params, author: Current.user)` — sets the created candidate's `author_id` to `author&.id`.

- [ ] **Step 1: Implement author capture**

In `app/services/candidate/create.rb`, change the constructor to accept `author:` (default `Current.user`):

```ruby
  def initialize(params, author: Current.user)
    @params = params
    @author = author
  end
```

Then inside `call`, add the `author_id` assignment right after the existing `base_version_id` line:

```ruby
      params[:candidate][:base_version_id] = base_version.id || nil
      params[:candidate][:author_id] = @author&.id
```

(No controller change: `CandidatesController#create` calls `Candidate::Create.new(params)`, which uses the `Current.user` default.)

- [ ] **Step 2: Add the service spec example**

In `spec/services/create_candidate_spec.rb`, inside `context "with no prior versions"` (before its closing `end`), add:

```ruby
    it "sets the author when one is passed" do
      Candidate::Create.new(valid_params, author: user).call
      expect(Candidate.last.author).to eq(user)
    end
```

- [ ] **Step 3: Add the request spec example (end-to-end Current.user)**

In `spec/requests/candidates_requests_spec.rb`, inside `describe "#create"`, add:

```ruby
    it "records the signed-in user as the author" do
      sign_in(user)
      post project_candidates_path(project.name), params: valid_params
      expect(Candidate.last.author).to eq(user)
    end
```

- [ ] **Step 4: Run the specs**

Run: `bundle exec rspec spec/services/create_candidate_spec.rb spec/requests/candidates_requests_spec.rb`
Expected: all green (existing examples still pass — default `author` is `nil` in the service spec, which is allowed).

- [ ] **Step 5: Commit**

```bash
git add app/services/candidate/create.rb spec/services/create_candidate_spec.rb spec/requests/candidates_requests_spec.rb
git commit -m "Capture candidate author on create"
```

---

### Task 3: Capture `decided_by` / `decided_at` in Merge and Reject

**Files:**
- Modify: `app/services/candidate/merge.rb`
- Modify: `app/services/candidate/reject.rb`
- Test: `spec/services/merge_candidate_spec.rb`, `spec/services/reject_candidate_spec.rb`

**Interfaces:**
- Consumes: `Candidate#decided_by=`, `Candidate#decided_at=` (Task 1); `Current.user`.
- Produces: `Candidate::Merge.new(candidate, decided_by: Current.user)` and `Candidate::Reject.new(candidate, decided_by: Current.user)` — both set `decided_by_id` and `decided_at` when the candidate leaves `open`.

- [ ] **Step 1: Implement in `Candidate::Merge`**

In `app/services/candidate/merge.rb`, change the constructor and set the fields before save:

```ruby
  def initialize(candidate, decided_by: Current.user)
    @candidate = candidate
    @version = @candidate.latest_version
    @project = @candidate.project
    @decided_by = decided_by
  end
```

Inside `call`, after `@candidate.merge`:

```ruby
      @candidate.merge
      @candidate.decided_by = @decided_by
      @candidate.decided_at = Time.current
      @candidate.save!
```

- [ ] **Step 2: Implement in `Candidate::Reject`**

In `app/services/candidate/reject.rb`, mirror it:

```ruby
  def initialize(candidate, decided_by: Current.user)
    @candidate = candidate
    @version = @candidate.latest_version
    @project = @candidate.project
    @decided_by = decided_by
  end
```

Inside `call`, after `@candidate.reject`:

```ruby
      @candidate.reject
      @candidate.decided_by = @decided_by
      @candidate.decided_at = Time.current
      @candidate.save!
```

(No controller changes: `MergesController` / `RejectionsController` call the services with just the candidate, using the `Current.user` default.)

- [ ] **Step 3: Add the merge service spec example**

In `spec/services/merge_candidate_spec.rb`, inside `context "given no prior versions"`, add:

```ruby
    it "records who decided and when" do
      Candidate::Merge.new(@candidate, decided_by: user).call
      expect(@candidate.reload.decided_by).to eq(user)
      expect(@candidate.decided_at).to be_within(5.seconds).of(Time.current)
    end
```

- [ ] **Step 4: Add the reject service spec example**

In `spec/services/reject_candidate_spec.rb`, add:

```ruby
  it "records who decided and when" do
    Candidate::Reject.new(@candidate, decided_by: user).call
    expect(@candidate.reload.decided_by).to eq(user)
    expect(@candidate.decided_at).to be_within(5.seconds).of(Time.current)
  end
```

- [ ] **Step 5: Run the specs**

Run: `bundle exec rspec spec/services/merge_candidate_spec.rb spec/services/reject_candidate_spec.rb`
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add app/services/candidate/merge.rb app/services/candidate/reject.rb spec/services/merge_candidate_spec.rb spec/services/reject_candidate_spec.rb
git commit -m "Record decided_by/decided_at on merge and reject"
```

---

### Task 4: Render attribution on the candidate and version pages

**Files:**
- Modify: `app/models/candidate.rb`
- Modify: `app/views/candidates/show.html.erb:2-14`
- Modify: `app/views/versions/show.html.erb:2-6`
- Test: `spec/requests/candidates_requests_spec.rb`, `spec/requests/versions_requests_spec.rb` (create)

**Interfaces:**
- Consumes: `Candidate#author`, `#decided_by`, `#merged?`/`#rejected?` (AASM), `Version#candidate`, `User#email_address`.
- Produces: `Candidate#attribution_parts` → `Array<String>`, e.g. `["Proposed by a@x.com", "Merged by b@x.com"]`.

- [ ] **Step 1: Add the model method**

In `app/models/candidate.rb`, add:

```ruby
  def attribution_parts
    parts = []
    parts << "Proposed by #{author.email_address}" if author
    if decided_by
      verb = merged? ? "Merged" : "Rejected"
      parts << "#{verb} by #{decided_by.email_address}"
    end
    parts
  end
```

- [ ] **Step 2: Render on the candidate page**

In `app/views/candidates/show.html.erb`, inside the left header `<div>`, after the name/badge inner `</div>` (after line 13, before the outer `</div>` on line 14), add:

```erb
    <% if @candidate.attribution_parts.any? %>
      <div class="text-sm text-gray-500 mt-1"><%= @candidate.attribution_parts.join(" · ") %></div>
    <% end %>
```

- [ ] **Step 3: Render on the version page**

In `app/views/versions/show.html.erb`, inside the left header `<div>`, after the date line (after line 5), add:

```erb
    <% if @version.candidate&.attribution_parts&.any? %>
      <div class="text-sm text-gray-500 mt-1"><%= @version.candidate.attribution_parts.join(" · ") %></div>
    <% end %>
```

- [ ] **Step 4: Add the candidate-show request specs (proposed + rejected branch)**

In `spec/requests/candidates_requests_spec.rb`, add an author `let` after line 6:

```ruby
  let(:author) { FactoryBot.create :user, email_address: "author@example.com", group: group }
```

Then inside `describe "#show"`:

```ruby
    it "shows who proposed the candidate" do
      authored = FactoryBot.create(:candidate, project: project, author: author)
      sign_in(user)
      get project_candidate_path(project.name, authored.name)
      expect(response.body).to include("Proposed by")
      expect(response.body).to include("author@example.com")
    end

    it "shows who rejected the candidate" do
      rejected = FactoryBot.create(:candidate, project: project, author: author, decided_by: user, aasm_state: "rejected")
      sign_in(user)
      get project_candidate_path(project.name, rejected.name)
      expect(response.body).to include("Rejected by")
      expect(response.body).to include("test@example.com")
    end
```

(The distinct `author@example.com` — different from the signed-in `test@example.com` — proves the "Proposed by" text comes from the candidate author, not the nav's current-user email. The rejected example covers the `Rejected`-verb branch of `attribution_parts`.)

- [ ] **Step 5: Add the version-show request spec**

Create `spec/requests/versions_requests_spec.rb`:

```ruby
require "rails_helper"

describe "Versions requests", type: :request do
  let(:group) { FactoryBot.create :group, name: "Test group" }
  let(:user) { FactoryBot.create :user, email_address: "test@example.com", group: group }
  let(:author) { FactoryBot.create :user, email_address: "author@example.com", group: group }
  let(:decider) { FactoryBot.create :user, email_address: "decider@example.com", group: group }
  let(:project) { FactoryBot.create :project, name: "project", group: group }

  describe "#show" do
    it "shows who proposed and merged the version" do
      candidate = FactoryBot.create(:candidate, project: project, author: author, decided_by: decider, aasm_state: "merged")
      version = FactoryBot.create(:version, project: project, candidate: candidate, name: "v1", order: 1)
      sign_in(user)
      get project_version_path(project.name, version.name)
      expect(response.status).to eq(200)
      expect(response.body).to include("Proposed by")
      expect(response.body).to include("author@example.com")
      expect(response.body).to include("Merged by")
      expect(response.body).to include("decider@example.com")
    end
  end
end
```

- [ ] **Step 6: Run the specs**

Run: `bundle exec rspec spec/requests/candidates_requests_spec.rb spec/requests/versions_requests_spec.rb`
Expected: all green.

- [ ] **Step 7: Full suite**

Run: `bundle exec rspec`
Expected: all green.

- [ ] **Step 8: Commit**

```bash
git add app/models/candidate.rb app/views/candidates/show.html.erb app/views/versions/show.html.erb spec/requests/candidates_requests_spec.rb spec/requests/versions_requests_spec.rb
git commit -m "Show candidate attribution on candidate and version pages"
```

---

## Manual verification (visual gate)

After Task 4, view it in the running app (`bin/dev`) — this stage has a visual deliverable:

1. Create a new candidate → its page shows "Proposed by <your email>".
2. Merge it → the resulting version page shows "Proposed by … · Merged by <your email>".
3. Reject a different candidate → its page shows "… · Rejected by <your email>".
4. An old seeded candidate/version (no attribution) renders with **no** attribution line (no error).

## Self-review notes

- **Spec coverage vs. design Stage 1:** `author_id` + `decided_by_id`/`decided_at` migration & associations (Task 1) ✓; capture author in Create (Task 2) ✓; capture decided_by/decided_at in Merge + Reject (Task 3) ✓; render "Proposed by … · Merged/Rejected by …" on candidate + version pages (Task 4) ✓.
- **Nullable throughout:** every task treats attribution as optional; views guard with `.any?` / `&.`.
- **Type consistency:** `author` and `decided_by` are `User`; columns are `author_id` / `decided_by_id` / `decided_at`; service keyword is `author:` / `decided_by:`; `attribution_parts` returns `Array<String>` and is joined with `" · "` in both views.
- **Not TDD:** implementation precedes tests in every task; no "verify it fails" steps.
