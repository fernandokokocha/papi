# Version ⇄ Candidate Navigation & Projects-Page Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users jump between a version and the candidate that produced it, and replace the projects page's two unrelated columns with one chronological history shown as a Table (default) or Timeline.

**Architecture:** Two independent changes. (1) Add reciprocal navigation buttons on the version and candidate show pages. (2) On the projects index, render each project's candidate history through two partials (table + timeline) toggled by a page-level segmented control backed by a tiny Stimulus controller + `localStorage`.

**Spec:** `docs/superpowers/specs/2026-07-11-version-candidate-navigation-design.md`

## Global Constraints

- **Palette:** White & Sky (see CLAUDE.md). Primary text `text-gray-900`, secondary `text-gray-500`, links `text-sky-700`, panels `bg-white border-gray-200`.
- **Tailwind classes are complete literal strings** — never interpolate (`bg-#{x}`). A hash mapping a key to full literal class strings is fine.
- **Turbo Drive is off.** No behavior here depends on Turbo navigation.
- **Tests:** RSpec (`bundle exec rspec`), FactoryBot factories in `spec/factories/`. Write tests alongside/after the implementation — do **not** write failing-test-first or add "verify it fails" steps.
- **Lean views:** no explanatory comments, no guards for invariant-impossible states.
- **Commits are deferred** — the user commits at their own discretion; do not commit autonomously. Each task ends with a verification checkpoint instead.

---

### Task 1: Model support — `Project#history` and `Candidate#promoted_version`

**Files:**
- Modify: `app/models/project.rb`
- Modify: `app/models/candidate.rb`
- Test: `spec/models/project_spec.rb` (create), `spec/models/candidate_spec.rb`

**Interfaces:**
- Produces: `Project#history` → candidates ordered `order: :desc`, eager-loading `:author, :decided_by, :versions, :comments`.
- Produces: `Candidate#promoted_version` → the promoted project `Version` when `merged?`, else `nil` (uses the loaded `versions` association).

- [ ] **Step 1: Add `Project#history`**

In `app/models/project.rb`, add:

```ruby
def history
  candidates.includes(:author, :decided_by, :versions, :comments).order(order: :desc)
end
```

- [ ] **Step 2: Add `Candidate#promoted_version`**

In `app/models/candidate.rb`, add:

```ruby
def promoted_version
  return nil unless merged?
  versions.max_by(&:order)
end
```

- [ ] **Step 3: Write model specs**

Create `spec/models/project_spec.rb`:

```ruby
require "rails_helper"

describe Project do
  describe "#history" do
    it "returns candidates newest-first" do
      project = FactoryBot.create(:project)
      first = FactoryBot.create(:candidate, project: project, name: "rc1", order: 1)
      second = FactoryBot.create(:candidate, project: project, name: "rc2", order: 2)

      expect(project.history.to_a).to eq([ second, first ])
    end
  end
end
```

Append to `spec/models/candidate_spec.rb` (inside `describe Candidate do`):

```ruby
  describe "#promoted_version" do
    it "returns the merged candidate's version" do
      candidate = FactoryBot.create(:candidate, aasm_state: "merged")
      version = FactoryBot.create(:version, candidate: candidate, name: "v1", order: 1)

      expect(candidate.promoted_version).to eq(version)
    end

    it "returns nil for an open candidate" do
      candidate = FactoryBot.create(:candidate, aasm_state: "open")
      FactoryBot.create(:version, candidate: candidate)

      expect(candidate.promoted_version).to be_nil
    end

    it "returns nil for a rejected candidate" do
      candidate = FactoryBot.create(:candidate, aasm_state: "rejected")
      FactoryBot.create(:version, candidate: candidate)

      expect(candidate.promoted_version).to be_nil
    end
  end
```

- [ ] **Step 4: Run the specs**

Run: `bundle exec rspec spec/models/project_spec.rb spec/models/candidate_spec.rb`
Expected: PASS (all green).

- [ ] **Step 5: Checkpoint** — report results to the user; no visual gate for this task.

---

### Task 2: Version → candidate button

**Files:**
- Modify: `app/views/versions/show.html.erb`
- Test: `spec/requests/versions_requests_spec.rb`

**Interfaces:**
- Consumes: `@version.candidate` (always present), `Project#name`, `Candidate#name`.

- [ ] **Step 1: Add the button**

In `app/views/versions/show.html.erb`, inside the right-hand button group (the `<div class="flex items-center gap-3">` that holds prev/next/New candidate), add as the **first** element:

```erb
<%= link_to "View candidate → #{@version.candidate.name}", project_candidate_path(@project.name, @version.candidate.name), class: "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50 text-sm font-medium px-4 py-2 rounded" %>
```

- [ ] **Step 2: Add a request spec**

In `spec/requests/versions_requests_spec.rb`, inside `describe "#show"`, add:

```ruby
    it "links to the candidate that produced the version" do
      sign_in(user)
      get project_version_path(project.name, version.name)

      expect(response.body).to include("View candidate")
      expect(response.body).to include(project_candidate_path(project.name, candidate.name))
    end
```

- [ ] **Step 3: Run the spec**

Run: `bundle exec rspec spec/requests/versions_requests_spec.rb`
Expected: PASS.

- [ ] **Step 4: Visual checkpoint**

Ask the user to open a version show page and confirm the "View candidate → …" button appears in the header and navigates to the candidate. Wait for approval before continuing.

---

### Task 3: Candidate → version button (merged only)

**Files:**
- Modify: `app/views/candidates/show.html.erb`
- Test: `spec/requests/candidates_requests_spec.rb`

**Interfaces:**
- Consumes: `Candidate#promoted_version` (Task 1), `Candidate#merged?`.

- [ ] **Step 1: Add the merged-state button**

In `app/views/candidates/show.html.erb`, the header currently ends the actions block with `<% if @candidate.open? %> … Edit/Reject/Merge … <% end %>`. Extend it to also handle the merged state:

```erb
  <% if @candidate.open? %>
    <div class="flex items-center gap-3">
      <%= button_to "Edit", edit_project_candidate_path(@project.name, @candidate.name), method: :get, class: "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50 text-sm font-medium px-4 py-2 rounded cursor-pointer" %>
      <%= button_to "Reject", project_candidate_rejection_path(@project.name, @candidate.name), class: "bg-red-600 hover:bg-red-700 text-white text-sm font-medium px-4 py-2 rounded cursor-pointer" %>
      <%= button_to "Merge", project_candidate_merge_path(@project.name, @candidate.name), class: "bg-emerald-600 hover:bg-emerald-700 text-white text-sm font-medium px-4 py-2 rounded cursor-pointer" %>
    </div>
  <% elsif @candidate.merged? %>
    <div class="flex items-center gap-3">
      <%= link_to "View version → #{@candidate.promoted_version.name}", project_version_path(@project.name, @candidate.promoted_version.name), class: "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50 text-sm font-medium px-4 py-2 rounded" %>
    </div>
  <% end %>
```

- [ ] **Step 2: Add request specs**

In `spec/requests/candidates_requests_spec.rb`, inside the `#show` describe block (mirror the file's existing `let` setup for `project`/`user`/`sign_in`), add:

```ruby
    it "links a merged candidate to its version" do
      merged = FactoryBot.create(:candidate, project: project, name: "rc1", aasm_state: "merged")
      version = FactoryBot.create(:version, project: project, candidate: merged, name: "v1", order: 1)
      sign_in(user)

      get project_candidate_path(project.name, merged.name)

      expect(response.body).to include("View version")
      expect(response.body).to include(project_version_path(project.name, version.name))
    end

    it "shows no version link for an open candidate" do
      open_candidate = FactoryBot.create(:candidate, project: project, name: "rc2", aasm_state: "open")
      sign_in(user)

      get project_candidate_path(project.name, open_candidate.name)

      expect(response.body).not_to include("View version")
    end
```

If `spec/requests/candidates_requests_spec.rb` has no `#show` describe block yet, add one and reuse the top-level `let(:group)/let(:user)/let(:project)` definitions from the file (same shape as `versions_requests_spec.rb`).

- [ ] **Step 3: Run the spec**

Run: `bundle exec rspec spec/requests/candidates_requests_spec.rb`
Expected: PASS.

- [ ] **Step 4: Visual checkpoint**

Ask the user to open a merged candidate and confirm the "View version → …" button appears and navigates to the version; confirm an open candidate shows Edit/Reject/Merge (no version button) and a rejected candidate shows no action buttons. Wait for approval.

---

### Task 4: History table replaces the two-column grid

**Files:**
- Create: `app/views/projects/_state_badge.html.erb`
- Create: `app/views/projects/_history_table.html.erb`
- Modify: `app/views/projects/index.html.erb`
- Test: `spec/requests/projects_requests_spec.rb`

**Interfaces:**
- Consumes: `Project#history`, `Candidate#promoted_version`, `Project#latest_version`.
- Produces: partials `projects/state_badge` (local: `state`) and `projects/history_table` (local: `project`); CSS hook class `view-table` on the table wrapper.

- [ ] **Step 1: Create the shared state badge partial**

Create `app/views/projects/_state_badge.html.erb`:

```erb
<%
  classes = {
    "open"     => "bg-yellow-50 text-yellow-700 border-yellow-200",
    "merged"   => "bg-emerald-50 text-emerald-700 border-emerald-200",
    "rejected" => "bg-red-50 text-red-700 border-red-200"
  }[state]
%>
<span class="text-xs font-semibold px-2.5 py-0.5 rounded-full border <%= classes %>"><%= state.capitalize %></span>
```

- [ ] **Step 2: Create the history table partial**

Create `app/views/projects/_history_table.html.erb`:

```erb
<% current_version = project.latest_version %>
<table class="w-full text-sm">
  <thead>
    <tr class="text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">
      <th class="px-3 py-2">Version</th>
      <th class="px-3 py-2">Candidate</th>
      <th class="px-3 py-2">State</th>
      <th class="px-3 py-2">Proposed</th>
      <th class="px-3 py-2">Decided</th>
      <th class="px-3 py-2">💬</th>
      <th class="px-3 py-2 text-right">Date</th>
    </tr>
  </thead>
  <tbody>
    <% project.history.each do |candidate| %>
      <% version = candidate.promoted_version %>
      <% current = version && version.id == current_version.id %>
      <tr class="border-t border-gray-100 <%= "bg-sky-50" if current %>">
        <td class="px-3 py-2.5">
          <% if version %>
            <%= link_to version.name, project_version_path(project.name, version.name), class: "font-semibold text-sky-700" %>
            <% if current %><span class="text-xs text-sky-600 font-semibold ml-1">current</span><% end %>
          <% else %>
            <span class="text-gray-300">—</span>
          <% end %>
        </td>
        <td class="px-3 py-2.5">
          <%= link_to candidate.name, project_candidate_path(project.name, candidate.name), class: "font-semibold text-sky-700" %>
        </td>
        <td class="px-3 py-2.5"><%= render "projects/state_badge", state: candidate.aasm_state %></td>
        <td class="px-3 py-2.5 text-gray-500"><%= candidate.author&.email_address || "—" %></td>
        <td class="px-3 py-2.5 text-gray-500"><%= candidate.decided_by&.email_address || "—" %></td>
        <td class="px-3 py-2.5 text-gray-500"><%= candidate.comments.size %></td>
        <td class="px-3 py-2.5 text-right text-xs text-gray-500"><%= candidate.created_at.strftime("%Y-%m-%d") %></td>
      </tr>
    <% end %>
  </tbody>
</table>
```

- [ ] **Step 3: Replace the two-column grid in the index**

In `app/views/projects/index.html.erb`, delete the entire `<div class="grid grid-cols-2 gap-6"> … </div>` block (both the Versions and Candidates columns) and replace it with:

```erb
      <div class="view-table">
        <%= render "projects/history_table", project: project %>
      </div>
```

Leave the project-card header (name + latest version link + New candidate button) unchanged.

- [ ] **Step 4: Add an index request spec**

In `spec/requests/projects_requests_spec.rb`, add:

```ruby
  describe "#index history" do
    let(:project) { FactoryBot.create(:project, name: "proj", group: group) }

    it "renders the candidate history with version mapping" do
      candidate = FactoryBot.create(:candidate, project: project, name: "rc1", aasm_state: "merged")
      FactoryBot.create(:version, project: project, candidate: candidate, name: "v1", order: 1)
      sign_in(user)

      get projects_path

      expect(response.body).to include("rc1")
      expect(response.body).to include(project_version_path(project.name, "v1"))
      expect(response.body).to include(project_candidate_path(project.name, "rc1"))
    end
  end
```

- [ ] **Step 5: Run the spec**

Run: `bundle exec rspec spec/requests/projects_requests_spec.rb`
Expected: PASS.

- [ ] **Step 6: Visual checkpoint**

Ask the user to open the projects page and confirm each project now shows a single history table (current version row tinted, version/candidate links working, rejected rows with an empty version cell). Wait for approval.

---

### Task 5: History timeline partial

**Files:**
- Create: `app/views/projects/_history_timeline.html.erb`
- Modify: `app/views/projects/index.html.erb`

**Interfaces:**
- Consumes: `Project#history`, `Candidate#promoted_version`, `Project#latest_version`, `projects/state_badge`.
- Produces: partial `projects/history_timeline` (local: `project`); CSS hook class `view-timeline` on the timeline wrapper.

> Until Task 6 wires the toggle, both the table and timeline render stacked — that is expected for this task's visual check.

- [ ] **Step 1: Create the timeline partial**

Create `app/views/projects/_history_timeline.html.erb`:

```erb
<% current_version = project.latest_version %>
<div class="relative">
  <% project.history.each do |candidate| %>
    <% version = candidate.promoted_version %>
    <% current = version && version.id == current_version.id %>
    <div class="flex gap-4">
      <div class="relative w-16 flex justify-center">
        <span class="absolute top-0 bottom-0 w-px bg-gray-200"></span>
        <% if candidate.merged? %>
          <span class="relative z-10 mt-3 inline-flex items-center justify-center rounded-full bg-sky-700 text-white text-xs font-bold <%= current ? "w-10 h-10 ring-4 ring-sky-200" : "w-8 h-8" %>"><%= version.name %></span>
        <% elsif candidate.rejected? %>
          <span class="relative z-10 mt-4 inline-flex items-center justify-center rounded-full bg-white border-2 border-red-300 text-red-500 w-5 h-5 text-xs">✕</span>
        <% else %>
          <span class="relative z-10 mt-4 inline-flex items-center justify-center rounded-full bg-amber-500 ring-4 ring-amber-200 w-6 h-6"></span>
        <% end %>
      </div>
      <div class="flex-1 py-3 border-b border-gray-100 <%= "opacity-60" if candidate.rejected? %>">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <% if current %><span class="text-xs font-semibold text-sky-700 uppercase tracking-wide">Current version</span><% end %>
            <% if version %>
              <%= link_to version.name, project_version_path(project.name, version.name), class: "font-semibold text-sky-700" %>
              <span class="text-gray-400">←</span>
            <% end %>
            <%= link_to candidate.name, project_candidate_path(project.name, candidate.name), class: "font-semibold text-gray-700" %>
            <%= render "projects/state_badge", state: candidate.aasm_state %>
          </div>
          <span class="text-xs text-gray-500"><%= candidate.created_at.strftime("%Y-%m-%d") %></span>
        </div>
        <div class="text-sm text-gray-500 mt-1">
          <% if candidate.author %>Proposed by <%= candidate.author.email_address %><% end %>
          <% if candidate.decided_by %> · <%= candidate.merged? ? "merged" : "rejected" %> by <%= candidate.decided_by.email_address %><% end %>
          · 💬 <%= candidate.comments.size %>
        </div>
      </div>
    </div>
  <% end %>
</div>
```

- [ ] **Step 2: Render the timeline in the index**

In `app/views/projects/index.html.erb`, directly after the `<div class="view-table"> … </div>` block added in Task 4, add:

```erb
      <div class="view-timeline">
        <%= render "projects/history_timeline", project: project %>
      </div>
```

- [ ] **Step 3: Run the projects request spec** (guards against template errors)

Run: `bundle exec rspec spec/requests/projects_requests_spec.rb`
Expected: PASS.

- [ ] **Step 4: Visual checkpoint**

Ask the user to open the projects page and confirm the timeline renders correctly below the table: merged candidates on version nodes (current enlarged + haloed), rejected as small ✕ nodes in chronological place, open pulsing at top, mapping/authors/comment counts shown. Wait for approval.

---

### Task 6: Segmented Table ⇄ Timeline toggle

**Files:**
- Create: `app/javascript/controllers/view_toggle_controller.js`
- Modify: `app/views/projects/index.html.erb`
- Modify: `app/assets/tailwind/application.css`

**Interfaces:**
- Consumes: CSS hook classes `view-table` / `view-timeline` (Tasks 4–5).
- Produces: Stimulus controller `view-toggle` with a `default` value and a `show` action taking a `view` param.

- [ ] **Step 1: Create the Stimulus controller**

Create `app/javascript/controllers/view_toggle_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Page-level Table ⇄ Timeline switch for the projects history. Sets
// data-view on the wrapper (CSS drives visibility + active tab styling)
// and remembers the choice in localStorage.
export default class extends Controller {
  static values = { default: String }

  connect() {
    const stored = localStorage.getItem("projects-view")
    this.apply(stored || this.defaultValue || "table")
  }

  show(event) {
    this.apply(event.params.view)
  }

  apply(view) {
    this.element.dataset.view = view
    localStorage.setItem("projects-view", view)
  }
}
```

- [ ] **Step 2: Wrap the page and add the segmented control**

In `app/views/projects/index.html.erb`, wrap the whole page in the controller and add the segmented pill to the header's right side (next to New project). The header + list become:

```erb
<div data-controller="view-toggle" data-view-toggle-default-value="table">
  <div class="mb-8 flex items-center justify-between">
    <h1 class="text-2xl font-semibold text-gray-900"><%= @group.name %></h1>
    <div class="flex items-center gap-3">
      <div class="inline-flex bg-slate-100 rounded-lg p-0.5">
        <button data-action="view-toggle#show" data-view-toggle-view-param="table" class="view-tab-table text-sm font-semibold px-3.5 py-1.5 rounded-md text-slate-500 cursor-pointer">Table</button>
        <button data-action="view-toggle#show" data-view-toggle-view-param="timeline" class="view-tab-timeline text-sm font-semibold px-3.5 py-1.5 rounded-md text-slate-500 cursor-pointer">Timeline</button>
      </div>
      <%= button_to "New project", new_project_path, method: :get, class: "bg-sky-600 hover:bg-sky-700 text-white text-sm font-medium px-4 py-2 rounded cursor-pointer" %>
    </div>
  </div>

  <div class="flex flex-col gap-3">
    <%# existing project-card loop stays here, unchanged %>
  </div>
</div>
```

Keep the existing `<% @projects.each do |project| %> … <% end %>` card loop exactly as-is inside the `flex flex-col gap-3` div. **Tag balance:** the file previously ended with the `</div>` that closes `flex flex-col gap-3`; wrapping the page in the new `data-controller="view-toggle"` div adds one more `</div>` at the very end of the file — make sure it's there so tags balance.

- [ ] **Step 3: Add the visibility + active-tab CSS**

Append to `app/assets/tailwind/application.css`:

```css
[data-view="table"] .view-timeline { display: none; }
[data-view="timeline"] .view-table { display: none; }

[data-view="table"] .view-tab-table,
[data-view="timeline"] .view-tab-timeline {
  background: #ffffff;
  color: #0369a1;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.08);
}
```

- [ ] **Step 4: Rebuild assets**

Run: `bin/rails tailwindcss:build`
Expected: builds without error (rebuilds `app/assets/builds/tailwind.css`; see the dev-asset memory if styles look stale).

- [ ] **Step 5: Visual checkpoint**

Ask the user to open the projects page and confirm: Table shows by default with the Table pill active; clicking Timeline switches all project cards to the timeline and highlights the Timeline pill; the choice persists across a full page reload (`localStorage`). Wait for approval.

---

## Notes for the implementer

- `sign_in(user)` is provided by the request-spec support helpers (see existing `*_requests_spec.rb`).
- Comment counts are totals including replies (`comments.size` on the eager-loaded association).
- Do not add a `versions` index route/controller — everything here reuses existing routes.
