# Read-only Comments in the Edit Candidate Form — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show an existing candidate's review comments read-only, inline next to the endpoint/entity they were pinned to, on the React-based edit candidate form.

**Architecture:** Comments are rendered to HTML strings server-side (reusing the existing `comments/*` partials in a new read-only mode) and passed into the React form as a `{card-identity → html}` map on `#react-form`. Each endpoint/entity card injects its blob via `dangerouslySetInnerHTML`, keyed by the card's *original* logical identity so comments stay pinned when a path/name is renamed mid-edit. Line-anchored comments render collapsed under their card and flip to an "Outdated" treatment once any edit is made.

**Tech Stack:** Rails 7 (ERB, Pundit), React 18 (Vite), Tailwind CSS v4, RSpec + FactoryBot.

## Global Constraints

- Design palette: White & Sky per `CLAUDE.md`. Outdated uses an amber accent; resolved uses the muted/secondary treatment (both already exist in `comments/*`).
- Tailwind classes must be **complete literal strings** (no interpolation); shared custom CSS lives in `app/assets/tailwind/application.css`.
- Tests are RSpec under `spec/` (`test/` holds only legacy fixtures). Write tests alongside/after implementation — no "verify it fails first" step. No JS unit framework: React is verified visually in the running app.
- Read-only means **no** compose / reply / resolve affordances anywhere on the edit page.
- Card identity key format (must match on both sides): endpoints `"#{http_verb} #{path}"` where `http_verb` is the string enum (`"verb_get"`, …); entities `name`. React uses `original_http_verb`/`original_path`/`original_name` so keys survive edits.
- Verification uses the seeded showcase candidate **rc4** in project **project1** (all `c4_*` fixtures). Its edit URL: `/projects/project1/candidates/rc4/edit`. `edit?` requires an **admin** user in the project's group.
- Commits happen **only on the user's go-ahead**, straight to `main`, no branch/PR, no `Co-Authored-By`. Each task ends at a user verification checkpoint; commit when told to.

---

## File Structure

**Stage 1 — React visuals with static data**
- Create: `app/javascript/components/CardComments.jsx` — injects one card's pre-rendered comment HTML; carries the `edited` class.
- Modify: `app/javascript/components/Form.jsx` — parse a new `comments` prop, pass map + `anyChanges` down.
- Modify: `app/javascript/components/EndpointList.jsx` — render `<CardComments>` after each `<Endpoint>`, keyed by original identity.
- Modify: `app/javascript/components/EntityList.jsx` — same for entities.
- Modify: `app/views/versions/_form.html.erb` — emit `data-comments` (static sample JSON in Stage 1).
- Modify: `app/assets/tailwind/application.css` — `.card-comments.edited .line-threads` Outdated treatment + reveal note.

**Stage 2 — real data from server**
- Modify: `app/views/comments/_thread.html.erb` — `read_only` gate on Reopen.
- Modify: `app/views/comments/_thread_body.html.erb` — `read_only` gate on reply form + Resolve.
- Create: `app/views/comments/_card_comments.html.erb` — read-only per-card thread list.
- Modify: `app/helpers/comments_helper.rb` — `card_threads_for_endpoint`, `card_threads_for_entity`, `card_comments_data`.
- Modify: `app/controllers/candidates_controller.rb` — `edit` loads categorized endpoints/entities + anchor map.
- Modify: `app/views/versions/_form.html.erb` — swap static sample for `card_comments_data(...)`.
- Test: `spec/requests/candidates_requests_spec.rb` — edit page renders read-only comments; empty when none.
- Test: `spec/helpers/comments_helper_spec.rb` — `card_threads_for_endpoint`/`_entity` bucketing.

---

## Stage 1 — React visuals with static data

### Task 1: Inline comment injection + edited/Outdated treatment (static data)

**Files:**
- Create: `app/javascript/components/CardComments.jsx`
- Modify: `app/javascript/components/Form.jsx`
- Modify: `app/javascript/components/EndpointList.jsx`
- Modify: `app/javascript/components/EntityList.jsx`
- Modify: `app/views/versions/_form.html.erb`
- Modify: `app/assets/tailwind/application.css`

**Interfaces:**
- Produces: `data-comments` attribute on `#react-form` = JSON `{ "endpoints": { "<verb> <path>": "<html>" }, "entities": { "<name>": "<html>" } }`. Stage 2 replaces the value but keeps this exact shape and key format.
- Produces: `CardComments` React component — props `{ html: string|undefined, edited: bool }`; renders nothing when `html` is falsy.

- [ ] **Step 1: Create `CardComments.jsx`**

```jsx
import React from 'react'

const CardComments = ({html, edited}) => {
    if (!html) return null
    return (
        <div className={edited ? "card-comments edited" : "card-comments"}>
            <div dangerouslySetInnerHTML={{__html: html}} />
        </div>
    )
}

export default CardComments
```

The `edited` class sits on this React-managed wrapper — outside the injected HTML — so toggling it never re-parses the blob.

- [ ] **Step 2: Parse the `comments` prop in `Form.jsx` and thread it down**

In `app/javascript/components/Form.jsx`, change the component signature (line 70) to accept the new prop and parse it once:

```jsx
const Form = ({serializedEndpoints, serializedEntities, comments}) => {
    const commentsMap = React.useMemo(
        () => (comments ? JSON.parse(comments) : {endpoints: {}, entities: {}}),
        [comments]
    )
```

Then pass `commentsMap` and the existing `anyChanges` into both lists. Update the `<EndpointList .../>` element (around line 317) to add:

```jsx
                comments={commentsMap.endpoints}
                edited={anyChanges}
```

and the `<EntityList .../>` element (around line 331) to add:

```jsx
                comments={commentsMap.entities}
                edited={anyChanges}
```

- [ ] **Step 3: Render `CardComments` in `EndpointList.jsx`**

In `app/javascript/components/EndpointList.jsx`: add `comments` and `edited` to the destructured props, import the component, and wrap each mapped endpoint so its comments render directly beneath the card. Replace the `endpoints.map(...)` block (lines 24–33) with:

```jsx
                {endpoints.map((endpoint) => {
                    const key = endpoint.type === 'new'
                        ? null
                        : `${endpoint.original_http_verb} ${endpoint.original_path}`
                    return (
                        <div key={endpoint.id}>
                            <Endpoint
                                endpoint={endpoint}
                                remove={removeEndpoint}
                                restore={restoreEndpoint}
                                updateEndpoint={updateEndpoint}
                                entities={entities}
                            />
                            <CardComments html={key && comments[key]} edited={edited} />
                        </div>
                    )
                })}
```

Add `import CardComments from "@/components/CardComments.jsx";` at the top and add `comments,` and `edited,` to the props destructuring (lines 5–17).

- [ ] **Step 4: Render `CardComments` in `EntityList.jsx`**

In `app/javascript/components/EntityList.jsx`: import `CardComments`, add `comments` and `edited` to the props (line 4), and replace the `entities.map(...)` block (lines 10–18) with:

```jsx
                {entities.map((entity) => {
                    const key = entity.type === 'new' ? null : entity.original_name
                    return (
                        <div key={entity.id}>
                            <Entity
                                entity={entity}
                                updateEntity={updateEntity}
                                removeEntity={removeEntity}
                                entities={entities}
                            />
                            <CardComments html={key && comments[key]} edited={edited} />
                        </div>
                    )
                })}
```

- [ ] **Step 5: Emit a static sample `data-comments` map from `_form.html.erb`**

In `app/views/versions/_form.html.erb`, add a `data-comments` attribute to the `#react-form` div (lines 22–26). For Stage 1 use a hardcoded sample keyed to two real rc4 cards so placement and the Outdated toggle are visible:

```erb
  <div
    id="react-form"
    data-serialized-endpoints="<%= @version.existing_endpoints_for_frontend %>"
    data-serialized-entities="<%= @version.existing_entities_for_frontend %>"
    data-comments="<%= {
      endpoints: {
        "verb_get /users" => %(<div class="flex flex-col gap-2 mt-3"><div class="comment-thread bg-sky-50/60 border border-gray-200 border-l-4 border-l-sky-600 rounded-lg shadow-sm p-3"><div class="text-sm font-semibold text-gray-900">one@example.com</div><div class="text-sm text-gray-700">Pagination looks right, but should total include soft-deleted users?</div></div><div class="line-threads flex flex-col gap-2"><div class="line-threads-edited-note text-xs text-amber-700 font-medium">Edited — comments below may be outdated</div><div class="comment-thread bg-indigo-50/60 border border-gray-200 border-l-4 border-l-indigo-500 rounded-lg shadow-sm p-3"><div class="text-xs text-gray-500 font-mono">GET /users → 200 → output · line 2</div><div class="text-sm text-gray-700">Do clients page through items[] or is total the source of truth?</div></div></div></div>)
      },
      entities: {
        "User" => %(<div class="flex flex-col gap-2 mt-3"><div class="comment-thread bg-violet-50/60 border border-gray-200 border-l-4 border-l-violet-600 rounded-lg shadow-sm p-3"><div class="text-sm font-semibold text-gray-900">one@example.com</div><div class="text-sm text-gray-700">avatar_url should be nullable — not every user uploads one.</div></div></div>)
      }
    }.to_json %>"
  ></div>
```

This is temporary scaffolding; Task 3 replaces the attribute value with a helper call.

- [ ] **Step 6: Add the edited → Outdated CSS**

In `app/assets/tailwind/application.css`, add:

```css
/* Read-only line comments in the edit form: dimmed until the form is edited,
   then given the amber "outdated" treatment (they will be outdated after save). */
.card-comments .line-threads-edited-note {
  display: none;
}
.card-comments.edited .line-threads {
  border-left: 3px solid var(--color-amber-400);
  padding-left: 0.5rem;
  opacity: 0.85;
}
.card-comments.edited .line-threads-edited-note {
  display: block;
}
```

- [ ] **Step 7: Rebuild assets and verify visually**

Run the dev server (`bin/dev`) — or rebuild directly with `bin/vite build` and `bin/rails tailwindcss:build` if assets look stale (see MEMORY: dev asset rebuild). As an admin dev user, open `/projects/project1/candidates/rc4/edit`.

Expected:
- The `GET /users` endpoint card shows the sample endpoint thread beneath it, and a collapsed line-thread block ("… line 2").
- The `User` entity card shows its sample thread beneath it.
- The line-threads block is dimmed with the note hidden; after editing anything in the form (e.g. change a response), the block gains the amber left border and the "Edited — comments below may be outdated" note appears.

- [ ] **Step 8: User verification checkpoint (visual gate)**

Stop here and get the user's sign-off on inline placement and the edited/Outdated behavior before wiring real data. Commit on their go-ahead.

---

## Stage 2 — real data from server

### Task 2: Read-only rendering path (partials + helpers)

**Files:**
- Modify: `app/views/comments/_thread.html.erb`
- Modify: `app/views/comments/_thread_body.html.erb`
- Create: `app/views/comments/_card_comments.html.erb`
- Modify: `app/helpers/comments_helper.rb`
- Test: `spec/helpers/comments_helper_spec.rb`

**Interfaces:**
- Consumes: `@comment_threads_by_anchor` (the in-memory `{anchor_key => [root threads]}` map from `Candidate#comment_threads_by_anchor`).
- Produces: `card_threads_for_endpoint(endpoint)` / `card_threads_for_entity(entity)` → `{ whole: [Comment], lines: [Comment] }` (whole sorted by `created_at`; lines sorted by `[line, created_at]`).
- Produces: `card_comments_data(endpoints, entities)` → JSON string `{ "endpoints" => {key => html}, "entities" => {name => html} }`, omitting cards with no threads; `"{}"` when `@comment_threads_by_anchor` is nil.
- Produces: `comments/_card_comments` partial — local `threads: {whole:, lines:}`; renders each thread read-only.
- Produces: `read_only` local on `comments/_thread` and `comments/_thread_body` — suppresses reply/resolve/reopen.

- [ ] **Step 1: Add `read_only` gate to `_thread.html.erb`**

In `app/views/comments/_thread.html.erb`, read the local at the top (after line 1):

```erb
<% read_only = local_assigns[:read_only] %>
```

Wrap the Reopen `button_to` (lines 24–28) so it is skipped when read-only:

```erb
        <% if !read_only && policy(comment).resolve? %>
          <%= button_to "Reopen", project_candidate_comment_resolution_path(comment.candidate.project.name, comment.candidate.name, comment),
                method: :delete, params: { line_badge: line_badge }, form: { data: { turbo: true } },
                class: "shrink-0 bg-white text-gray-700 border border-gray-300 hover:bg-gray-50 text-xs font-medium px-3 py-1.5 rounded cursor-pointer" %>
        <% end %>
```

Pass `read_only` through both `render "comments/thread_body"` calls (lines 31 and 35):

```erb
        <%= render "comments/thread_body", comment: comment, line_badge: line_badge, read_only: read_only %>
```

- [ ] **Step 2: Add `read_only` gate to `_thread_body.html.erb`**

In `app/views/comments/_thread_body.html.erb`, read the local at the top:

```erb
<% read_only = local_assigns[:read_only] %>
```

Wrap the reply-form block (lines 8–10) and the Resolve block (lines 11–17) so both are skipped when read-only:

```erb
<% unless read_only %>
  <div id="<%= dom_id(comment, :reply_form) %>" class="border-t border-gray-200 px-3 py-2.5" data-controller="reply">
    <%= render "comments/reply_form", parent: comment, line_badge: line_badge %>
  </div>
  <% if policy(comment).resolve? && !comment.resolved? %>
    <div class="border-t border-gray-200 px-3 py-1.5 flex justify-end">
      <%= button_to "Resolve thread", project_candidate_comment_resolution_path(comment.candidate.project.name, comment.candidate.name, comment),
            params: { line_badge: line_badge }, form: { data: { turbo: true } },
            class: "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50 text-xs font-medium px-3 py-1.5 rounded cursor-pointer" %>
    </div>
  <% end %>
<% end %>
```

(The `comments/comment` render and the replies list above stay — replies are read-only content, not an affordance.)

- [ ] **Step 3: Add the card-thread helpers to `comments_helper.rb`**

Append to `app/helpers/comments_helper.rb` (inside the module):

```ruby
  # All root threads for one endpoint card, split into whole-scope (endpoint /
  # response, line unset) and line-anchored (line set). Scans the in-memory map
  # by logical identity; [] outside candidate context.
  def card_threads_for_endpoint(endpoint)
    return { whole: [], lines: [] } unless @comment_threads_by_anchor

    verb = Endpoint.http_verbs[endpoint.http_verb]
    whole, lines = [], []
    @comment_threads_by_anchor.each do |(scope, path, v, _name, _code, _part, line), threads|
      next unless %w[endpoint response].include?(scope) && path == endpoint.path && v == verb
      (line.nil? ? whole : lines).concat(threads)
    end
    { whole: whole.sort_by(&:created_at), lines: lines.sort_by { |c| [ c.line, c.created_at ] } }
  end

  # All root threads for one entity card, split like card_threads_for_endpoint.
  def card_threads_for_entity(entity)
    return { whole: [], lines: [] } unless @comment_threads_by_anchor

    whole, lines = [], []
    @comment_threads_by_anchor.each do |(scope, _path, _v, name, _code, _part, line), threads|
      next unless scope == "entity" && name == entity.name
      (line.nil? ? whole : lines).concat(threads)
    end
    { whole: whole.sort_by(&:created_at), lines: lines.sort_by { |c| [ c.line, c.created_at ] } }
  end

  # JSON map of pre-rendered read-only comment HTML per card, for injection into
  # the React edit form. Keyed by logical identity React can reconstruct:
  # endpoints "<http_verb> <path>", entities by name. Cards with no threads are
  # omitted. "{}" outside candidate context.
  def card_comments_data(endpoints, entities)
    return "{}".html_safe unless @comment_threads_by_anchor

    data = { endpoints: {}, entities: {} }
    endpoints.each do |endpoint|
      threads = card_threads_for_endpoint(endpoint)
      next if threads[:whole].empty? && threads[:lines].empty?
      data[:endpoints]["#{endpoint.http_verb} #{endpoint.path}"] = render("comments/card_comments", threads: threads)
    end
    entities.each do |entity|
      threads = card_threads_for_entity(entity)
      next if threads[:whole].empty? && threads[:lines].empty?
      data[:entities][entity.name] = render("comments/card_comments", threads: threads)
    end
    data.to_json
  end
```

- [ ] **Step 4: Create `comments/_card_comments.html.erb`**

```erb
<div class="flex flex-col gap-2 mt-3">
  <% threads[:whole].each do |thread| %>
    <%= render "comments/thread", comment: thread, read_only: true %>
  <% end %>
  <% if threads[:lines].any? %>
    <div class="line-threads flex flex-col gap-2">
      <div class="line-threads-edited-note text-xs text-amber-700 font-medium">Edited — comments below may be outdated</div>
      <% threads[:lines].each do |thread| %>
        <%= render "comments/thread", comment: thread, read_only: true, line_badge: :collapsed %>
      <% end %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 5: Add helper specs**

In `spec/helpers/comments_helper_spec.rb`, add examples covering the bucketing (follow the file's existing setup for `@comment_threads_by_anchor` / candidate). Example shape:

```ruby
describe "#card_threads_for_endpoint" do
  it "splits an endpoint's threads into whole-scope and line-anchored" do
    candidate = FactoryBot.create(:candidate)
    endpoint = FactoryBot.create(:endpoint, version: candidate.latest_version, http_verb: :verb_get, path: "/users")
    whole = FactoryBot.create(:comment, candidate: candidate, scope: "endpoint", part: "whole",
                              endpoint_path: "/users", endpoint_http_verb: 0)
    line = FactoryBot.create(:comment, candidate: candidate, scope: "response", part: "output", line: 2,
                             endpoint_path: "/users", endpoint_http_verb: 0, response_code: "200",
                             anchor_snapshot: "x")
    assign(:comment_threads_by_anchor, candidate.comment_threads_by_anchor)

    result = helper.card_threads_for_endpoint(endpoint)
    expect(result[:whole]).to eq([whole])
    expect(result[:lines]).to eq([line])
  end
end
```

Adjust factory calls to match the real `comment`/`endpoint` factories (check `spec/factories/comments.rb` for scope traits — prefer a trait if one exists). Run:

```bash
bundle exec rspec spec/helpers/comments_helper_spec.rb
```

Expected: PASS.

- [ ] **Step 6: Commit on the user's go-ahead**

Nothing user-visible changed yet (the edit page still uses the static sample). This is a safe internal commit point once the user approves.

### Task 3: Wire real data into the edit form

**Files:**
- Modify: `app/controllers/candidates_controller.rb`
- Modify: `app/views/versions/_form.html.erb`
- Test: `spec/requests/candidates_requests_spec.rb`

**Interfaces:**
- Consumes: `card_comments_data(@categorized_endpoints, @categorized_entities)` from Task 2.
- Produces: the edit page's `#react-form` `data-comments` attribute now carries real per-card comment HTML.

- [ ] **Step 1: Load categorized endpoints/entities + anchor map in `edit`**

In `app/controllers/candidates_controller.rb`, replace the `edit` action body so it mirrors `show`'s data loading:

```ruby
  def edit
    @project = Project.find_by!(name: params[:project_name])
    @candidate = Candidate.find_by!(name: params[:name], project: @project)
    authorize @candidate

    @version = @candidate.latest_version
    @previous_version = @candidate.base_version || Version.null_version(@project)

    @categorized_endpoints = Version::CategorizeByName.new(@previous_version.endpoints, @version.endpoints).call
    @categorized_entities = Version::CategorizeByName.new(@previous_version.entities, @version.entities).call

    @comment_threads_by_anchor = @candidate.comment_threads_by_anchor
  end
```

- [ ] **Step 2: Swap the static sample for the real map in `_form.html.erb`**

In `app/views/versions/_form.html.erb`, replace the static `data-comments` value from Task 1 Step 5 with the helper call:

```erb
    data-comments="<%= card_comments_data(@categorized_endpoints, @categorized_entities) %>"
```

- [ ] **Step 3: Add an edit-page request spec**

In `spec/requests/candidates_requests_spec.rb`, add a `#edit` describe block. Use an admin user in the project's group and a candidate with a couple of anchored comments:

```ruby
describe "#edit" do
  it "renders anchored comments read-only in the form data" do
    candidate = FactoryBot.create :candidate, project: project, name: "rc7"
    endpoint = FactoryBot.create :endpoint, version: candidate.latest_version, http_verb: :verb_get, path: "/users"
    FactoryBot.create :comment, candidate: candidate, scope: "endpoint", part: "whole",
                      endpoint_path: "/users", endpoint_http_verb: 0, body: "Please paginate"
    sign_in(admin)

    get edit_project_candidate_path(project.name, candidate.name)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Please paginate")
    expect(response.body).to include("verb_get /users")
    # read-only: no reply/resolve affordances
    expect(response.body).not_to include("Resolve thread")
  end

  it "sends an empty comments map for a candidate with no comments" do
    candidate = FactoryBot.create :candidate, project: project, name: "rc8"
    sign_in(admin)

    get edit_project_candidate_path(project.name, candidate.name)

    expect(response.body).to include(%(data-comments="{}"))
  end
end
```

Adjust factory setup to match `spec/requests/candidates_requests_spec.rb`'s existing `let`s (`admin`, `project`, `group`) and the real `endpoint`/`comment` factories. Note the response HTML-escapes the JSON, so assert on the escaped form if needed (e.g. `verb_get /users` appears inside an escaped attribute — match a substring that survives escaping, or use `CGI.unescapeHTML(response.body)`).

Run:

```bash
bundle exec rspec spec/requests/candidates_requests_spec.rb
```

Expected: PASS.

- [ ] **Step 4: Full visual verification on rc4**

Rebuild assets if needed, then open `/projects/project1/candidates/rc4/edit` as an admin dev user. Expected:
- `GET /users` card: the endpoint whole-thread ("Pagination looks right…" + its reply) and, in a collapsed line block, "Do clients page through items[]…" (line 2).
- `PUT /users/me` card: the note thread ("The note should list which fields are editable.").
- `DELETE /users/me` (removed) card: "Goodbye DELETE /users/me…".
- `GET /audit-logs` (added) card: "New audit log listing…".
- `User` entity card: root thread ("avatar_url should be nullable…").
- Editing anything flips every line-threads block to the amber Outdated treatment with its note shown.
- No reply boxes, Resolve, or Reopen buttons anywhere.

- [ ] **Step 5: Run the full suite and commit on go-ahead**

```bash
bundle exec rspec
bin/rubocop
```

Expected: green. Commit to `main` on the user's go-ahead.

---

## Self-Review Notes

- **Spec coverage:** server anchor-map load (T3S1), `card_comments_data` + read-only partials (T2), React injection keyed by original identity (T1S3–4), line comments collapsed + edited→Outdated (T1S6, T2S4), read-only suppression (T2S1–2), empty for new candidate (T3S3), staging split visuals/real-data (Stage 1/2). All spec sections mapped.
- **Key/type consistency:** identity key `"#{http_verb} #{path}"` and `name` used identically in `card_comments_data` (Ruby) and `EndpointList`/`EntityList` (JS via `original_http_verb`/`original_path`/`original_name`). `card_threads_for_*` return `{whole:, lines:}` consumed by `_card_comments`. `read_only` local consistent across `_thread`/`_thread_body`/`_card_comments`.
- **Fixture note:** rc4 is `merged`; the edit action does not gate on state, so its edit page renders for verification. If policy/state gating is later added, switch the visual check to an open candidate seeded with comments.
