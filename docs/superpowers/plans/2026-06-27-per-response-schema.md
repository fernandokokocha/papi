# Per-Response Schemas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the body schema from two fixed endpoint columns (`output`, `output_error`) onto each `Response` so every HTTP status code owns its own schema + note, mapping cleanly to OpenAPI's `responses` object.

**Architecture:** Additive-first refactor. Add `output` to `responses` and migrate all consumers to read it while the old endpoint columns still exist; do the breaking column drop last so the test suite stays green at every commit. The candidate diff reuses the existing `Diff::FromValues` engine via a thin `DiffResponses` orchestrator; the React form renders one schema editor per response.

**Tech Stack:** Rails 8 / ActiveRecord (SQLite), RSpec + FactoryBot, React (Vite) with a bespoke JSON-schema editor, Tailwind v4. No JS test framework exists.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-06-27-per-response-schema-design.md`.
- DB is reset via `bin/rails dev:setup` (migrations edited **in place**, then `db:fixtures:load`). No data migration; dev data lives in `test/fixtures/*.yml`, not `db/seeds.rb`. Fixtures are NOT loaded by the RSpec suite (suite uses FactoryBot).
- Tests are RSpec in `spec/`; run with `bundle exec rspec`. Lint with `bin/rubocop`.
- No system/E2E tests in this work.
- Schema strings are parsed by `JSONSchemaParser`; an empty string parses to `Node::Nothing`. Empty bodies (204, DELETE) are represented by `""` / the `"nothing"` primitive.
- Response **codes are immutable** (add/remove only). An endpoint must end up with ≥ 1 response (enforced in the React form).
- Tailwind: write complete literal class strings only.
- Commit straight to `main`, no Co-Authored-By trailer.

---

## File Structure

**Backend**
- `db/migrate/20250702152843_create_responses.rb` — add `output` column (edit in place).
- `db/migrate/20250219083627_create_endpoints.rb` — drop `output`/`output_error` (edit in place, Task 5).
- `app/models/response.rb` — add `parsed_output`, drop `serialize` stub.
- `app/models/endpoint.rb` — drop `parsed_output`/`parsed_output_error`, simplify `differs_from?` (Task 5).
- `app/models/version.rb` — `existing_endpoints_for_frontend` (Task 4).
- `app/models/diff_responses/response_diff.rb` — NEW per-code diff value object.
- `app/models/diff_responses/from_responses.rb` — rewrite to `#lines`.
- `app/models/diff_responses/line.rb` — DELETE.
- `app/services/candidate/create.rb`, `app/services/candidate/update.rb` — `format_responses`.
- `app/controllers/test_server_controller.rb` — by-code lookup.

**Views**
- `app/views/specs/_responses.html.erb` — rewrite to render per-code blocks for a side.
- `app/views/endpoints/_endpoint_diff.html.erb`, `_endpoint_new.html.erb`, `_endpoint_removed.html.erb` — switch Responses section to new partial; remove Output sections (Task 5).

**React**
- `app/javascript/components/EndpointAdded.jsx`, `EndpointDiff.jsx`, `EndpointRemoved.jsx`, `Form.jsx`.

**Fixtures / factories / specs**
- `test/fixtures/responses.yml` (Task 1), `test/fixtures/endpoints.yml` (Task 5).
- `spec/factories/responses.rb` (Task 1), `spec/factories/endpoints.rb` (Task 5).
- `spec/models/response_spec.rb` (NEW), `spec/models/diff_responses/from_responses_spec.rb` (NEW), `spec/requests/test_server_requests_spec.rb` (NEW).
- `spec/services/create_candidate_spec.rb`, `spec/requests/candidates_requests_spec.rb`, `spec/requests/endpoints_requests_spec.rb`, `spec/models/endpoint_spec.rb`.

---

## Task 1: Add `output` to responses + `Response#parsed_output`

Additive and non-breaking — endpoint columns untouched.

**Files:**
- Modify: `db/migrate/20250702152843_create_responses.rb`
- Modify: `app/models/response.rb`
- Modify: `spec/factories/responses.rb`
- Modify: `test/fixtures/responses.yml`
- Test: `spec/models/response_spec.rb` (create)

**Interfaces:**
- Produces: `Response#parsed_output -> Node::*` (a parsed schema node, using the endpoint's version entities).

- [ ] **Step 1: Write the failing spec**

Create `spec/models/response_spec.rb`:

```ruby
require "rails_helper"

describe Response, type: :model do
  let(:group) { FactoryBot.create(:group) }
  let(:project) { FactoryBot.create(:project, group: group) }
  let(:candidate) { FactoryBot.create(:candidate, project: project) }
  let(:version) { FactoryBot.create(:version, project: project, candidate: candidate) }
  let(:endpoint) { FactoryBot.create(:endpoint, version: version) }

  describe "#parsed_output" do
    it "parses an empty output as Nothing" do
      response = FactoryBot.create(:response, endpoint: endpoint, code: "204", output: "")
      expect(response.parsed_output).to be_a(Node::Nothing)
    end

    it "parses a primitive output" do
      response = FactoryBot.create(:response, endpoint: endpoint, code: "200", output: "string")
      expect(response.parsed_output).to be_a(Node::Primitive)
    end

    it "resolves entity references using the version entities" do
      FactoryBot.create(:entity, version: version, name: "User", root: "{ name: string }")
      response = FactoryBot.create(:response, endpoint: endpoint, code: "200", output: "User")
      expect(response.parsed_output).to be_a(Node::Entity)
    end
  end
end
```

- [ ] **Step 2: Run it; expect failure**

Run: `bundle exec rspec spec/models/response_spec.rb`
Expected: FAIL — `output` is not a column / `parsed_output` undefined.

- [ ] **Step 3: Add the migration column (edit in place)**

In `db/migrate/20250702152843_create_responses.rb`, add the `output` line inside `create_table :responses`:

```ruby
class CreateResponses < ActiveRecord::Migration[8.0]
  def change
    create_table :responses do |t|
      t.string :code, null: false
      t.string :note, null: false, default: ""
      t.string :output, null: false, default: ""
      t.references :endpoint, null: false, foreign_key: true

      t.timestamps
    end

    add_index :responses, [ :endpoint_id, :code ], unique: true
  end
end
```

- [ ] **Step 4: Rebuild the test DB schema**

Run: `bin/rails db:migrate:reset RAILS_ENV=test`
Expected: schema rebuilt; `responses.output` present in `db/schema.rb`.

- [ ] **Step 5: Implement `Response#parsed_output` and drop the stub**

Replace `app/models/response.rb` with:

```ruby
class Response < ApplicationRecord
  belongs_to :endpoint

  validates :code, uniqueness: { scope: :endpoint_id }

  def parsed_output
    parser = JSONSchemaParser.new(endpoint.version.entities)
    parser.parse_value(output)
  end
end
```

- [ ] **Step 6: Add `output` to the response factory**

`spec/factories/responses.rb`:

```ruby
FactoryBot.define do
  factory :response do
    code { "200" }
    note { "MyString" }
    output { "" }
    association :endpoint
  end
end
```

- [ ] **Step 7: Run the spec; expect pass**

Run: `bundle exec rspec spec/models/response_spec.rb`
Expected: PASS (3 examples).

- [ ] **Step 8: Populate `output` in the response fixtures**

In `test/fixtures/responses.yml`, add `output:` to every response, using this deterministic rule: copy the owning endpoint's old `output` if the code starts with `"2"`, otherwise copy the endpoint's old `output_error`. (Endpoint outputs are still in `test/fixtures/endpoints.yml`.)

Worked example for the v1 block — apply the same rule to every entry in the file:

```yaml
# ===== v1 =====
p1v1_users_list_200: { endpoint: p1v1_users_list, code: "200", output: "[User]" }
p1v1_users_list_403: { endpoint: p1v1_users_list, code: "403", output: "Error" }
p1v1_users_create_201: { endpoint: p1v1_users_create, code: "201", output: "User" }
p1v1_users_create_400: { endpoint: p1v1_users_create, code: "400", output: "Error" }
p1v1_users_create_403: { endpoint: p1v1_users_create, code: "403", output: "Error" }
p1v1_users_get_200: { endpoint: p1v1_users_get, code: "200", output: "User" }
p1v1_users_get_403: { endpoint: p1v1_users_get, code: "403", output: "Error" }
p1v1_users_get_404: { endpoint: p1v1_users_get, code: "404", output: "Error" }
p1v1_users_delete_200: { endpoint: p1v1_users_delete, code: "200", output: "boolean" }
p1v1_users_delete_403: { endpoint: p1v1_users_delete, code: "403", output: "Error" }
p1v1_users_delete_404: { endpoint: p1v1_users_delete, code: "404", output: "Error" }
p1v1_sessions_create_201: { endpoint: p1v1_sessions_create, code: "201", output: "Session" }
p1v1_sessions_create_401: { endpoint: p1v1_sessions_create, code: "401", output: "Error" }
```

- [ ] **Step 9: Verify the full suite is still green**

Run: `bundle exec rspec`
Expected: PASS (no regressions).

- [ ] **Step 10: Commit**

```bash
git add db/migrate/20250702152843_create_responses.rb app/models/response.rb \
        spec/factories/responses.rb spec/models/response_spec.rb test/fixtures/responses.yml
git commit -m "Add output schema column to responses"
```

---

## Task 2: Rewrite the response diff (per-code orchestrator) + views Responses section

Replaces `DiffResponses::Line` with `DiffResponses::ResponseDiff`, makes `FromResponses` return a single sorted `#lines` list, and rewires the three endpoint views' Responses section. The endpoint-level Output sections stay (removed in Task 5); they render alongside the new per-code blocks temporarily.

**Files:**
- Create: `app/models/diff_responses/response_diff.rb`
- Modify: `app/models/diff_responses/from_responses.rb`
- Delete: `app/models/diff_responses/line.rb`
- Modify: `app/views/specs/_responses.html.erb`
- Modify: `app/views/endpoints/_endpoint_diff.html.erb`, `_endpoint_new.html.erb`, `_endpoint_removed.html.erb`
- Test: `spec/models/diff_responses/from_responses_spec.rb` (create)

**Interfaces:**
- Consumes: `Response#parsed_output` (Task 1), `DiffText::FromNotes`, `Diff::FromValues`, `Node::Nothing`.
- Produces:
  - `DiffResponses::ResponseDiff` with readers `code`, `state` (`:added|:removed|:changed|:no_change`), `note_diff` (`DiffText::FromNotes`), `output_diff` (`Diff::FromValues`), `before_present?`, `after_present?`.
  - `DiffResponses::FromResponses.new(responses1, responses2, expanded: false)` with `#lines -> [ResponseDiff]` (sorted by code) and `#any_changes?`.

- [ ] **Step 1: Write the failing spec**

Create `spec/models/diff_responses/from_responses_spec.rb`:

```ruby
require "rails_helper"

describe DiffResponses::FromResponses, type: :model do
  let(:group) { FactoryBot.create(:group) }
  let(:project) { FactoryBot.create(:project, group: group) }
  let(:candidate) { FactoryBot.create(:candidate, project: project) }
  let(:version) { FactoryBot.create(:version, project: project, candidate: candidate) }
  let(:endpoint) { FactoryBot.create(:endpoint, version: version) }

  def response(code, note: "", output: "string")
    FactoryBot.build(:response, endpoint: endpoint, code: code, note: note, output: output)
  end

  it "sorts lines by code over the union of both sides" do
    diff = described_class.new([ response("200") ], [ response("404"), response("200") ])
    expect(diff.lines.map(&:code)).to eq(%w[200 404])
  end

  it "marks a response present only on the right as added" do
    diff = described_class.new([], [ response("201") ])
    line = diff.lines.first
    expect(line.state).to eq(:added)
    expect(line.before_present?).to be(false)
    expect(line.after_present?).to be(true)
  end

  it "marks a response present only on the left as removed" do
    diff = described_class.new([ response("500") ], [])
    expect(diff.lines.first.state).to eq(:removed)
  end

  it "marks a response with a changed schema as changed" do
    diff = described_class.new([ response("200", output: "string") ],
                              [ response("200", output: "number") ])
    expect(diff.lines.first.state).to eq(:changed)
  end

  it "marks a response with a changed note as changed" do
    diff = described_class.new([ response("200", note: "old") ],
                              [ response("200", note: "new") ])
    expect(diff.lines.first.state).to eq(:changed)
  end

  it "marks an identical response as no_change" do
    diff = described_class.new([ response("200", note: "n", output: "string") ],
                              [ response("200", note: "n", output: "string") ])
    expect(diff.lines.first.state).to eq(:no_change)
  end

  it "any_changes? is true when any line changed" do
    expect(described_class.new([], [ response("200") ]).any_changes?).to be(true)
    expect(described_class.new([ response("200") ], [ response("200") ]).any_changes?).to be(false)
  end
end
```

- [ ] **Step 2: Run it; expect failure**

Run: `bundle exec rspec spec/models/diff_responses/from_responses_spec.rb`
Expected: FAIL — `ResponseDiff` missing / `lines` undefined.

- [ ] **Step 3: Create `DiffResponses::ResponseDiff`**

`app/models/diff_responses/response_diff.rb`:

```ruby
class DiffResponses::ResponseDiff
  attr_reader :code, :state, :note_diff, :output_diff

  def initialize(code:, state:, note_diff:, output_diff:, before_present:, after_present:)
    @code = code
    @state = state
    @note_diff = note_diff
    @output_diff = output_diff
    @before_present = before_present
    @after_present = after_present
  end

  def before_present? = @before_present
  def after_present? = @after_present
end
```

- [ ] **Step 4: Rewrite `DiffResponses::FromResponses`**

`app/models/diff_responses/from_responses.rb`:

```ruby
class DiffResponses::FromResponses
  attr_reader :lines

  def initialize(responses1, responses2, expanded: false)
    @expanded = expanded
    by_code1 = responses1.index_by(&:code)
    by_code2 = responses2.index_by(&:code)
    codes = (by_code1.keys + by_code2.keys).uniq.sort

    @lines = codes.map { |code| build_line(code, by_code1[code], by_code2[code]) }
  end

  def any_changes?
    @lines.any? { |line| line.state != :no_change }
  end

  private

  def build_line(code, before, after)
    note_diff = DiffText::FromNotes.new(before&.note, after&.note)
    output_diff = Diff::FromValues.new(output_value(before), output_value(after))

    state =
      if before.nil?
        :added
      elsif after.nil?
        :removed
      elsif note_diff.any_changes? || output_diff.any_changes?
        :changed
      else
        :no_change
      end

    DiffResponses::ResponseDiff.new(
      code: code, state: state, note_diff: note_diff, output_diff: output_diff,
      before_present: !before.nil?, after_present: !after.nil?
    )
  end

  def output_value(response)
    return Node::Nothing.new if response.nil?
    value = response.parsed_output
    @expanded ? value.expand : value
  end
end
```

- [ ] **Step 5: Delete the obsolete `Line` class**

```bash
git rm app/models/diff_responses/line.rb
```

- [ ] **Step 6: Run the spec; expect pass**

Run: `bundle exec rspec spec/models/diff_responses/from_responses_spec.rb`
Expected: PASS (7 examples).

- [ ] **Step 7: Rewrite the `specs/_responses` partial to render per-code blocks**

Replace `app/views/specs/_responses.html.erb` (consumes locals `lines:` and `side:`):

```erb
<div>
  <% lines.each do |line| %>
    <% present = side == :before ? line.before_present? : line.after_present? %>
    <% color = case line.state
               when :added then "border-emerald-200 bg-emerald-50"
               when :removed then "border-red-200 bg-red-50"
               when :changed then "border-amber-200 bg-amber-50"
               else "border-gray-200 bg-white" end %>
    <div class="border rounded-md mb-2 <%= present ? color : "border-transparent" %>">
      <% if present %>
        <div class="px-2 py-1 text-xs font-mono text-gray-600">
          <span class="font-semibold"><%= line.code %></span>
          <%= render "specs/text", diff: (side == :before ? line.note_diff.before : line.note_diff.after) %>
        </div>
        <div class="pl-2 py-1">
          <%= render "specs/json", diff: (side == :before ? line.output_diff.before : line.output_diff.after) %>
        </div>
      <% else %>
        <div class="px-2 py-1 text-xs text-gray-300 font-mono"><%= line.code %></div>
      <% end %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 8: Wire the diff view to the new partial + pass `expanded`**

In `app/views/endpoints/_endpoint_diff.html.erb`:

Change the responses-diff construction line to pass `expanded`:

```erb
<% responses_diff = DiffResponses::FromResponses.new(previous_endpoint.responses, endpoint.responses, expanded: expanded) %>
```

Replace the left-column Responses render:

```erb
<div class="pl-2 py-2 bg-white border-b border-gray-200"><%= render "specs/responses", lines: responses_diff.lines, side: :before %></div>
```

Replace the right-column Responses render:

```erb
<div class="pl-2 py-2 bg-white border-b border-gray-200"><%= render "specs/responses", lines: responses_diff.lines, side: :after %></div>
```

(Leave the existing "Output" / "Output for Errors" sections in place for now.)

- [ ] **Step 9: Wire the "new" and "removed" views**

In `app/views/endpoints/_endpoint_new.html.erb` change:

```erb
<% responses_diff = DiffResponses::FromResponses.new([], endpoint.responses, expanded: expanded) %>
```
and the Responses render:
```erb
<div class="pl-2 py-2 bg-white border-b border-gray-200"><%= render "specs/responses", lines: responses_diff.lines, side: :after %></div>
```

In `app/views/endpoints/_endpoint_removed.html.erb` change:

```erb
<% responses_diff = DiffResponses::FromResponses.new(endpoint.responses, [], expanded: expanded) %>
```
and the Responses render:
```erb
<div class="pl-2 py-2 bg-white border-b border-gray-200"><%= render "specs/responses", lines: responses_diff.lines, side: :before %></div>
```

- [ ] **Step 10: Run the full suite (request specs render these views)**

Run: `bundle exec rspec`
Expected: PASS. If a request spec builds endpoints without responses, the lines list is empty and blocks simply don't render.

- [ ] **Step 11: Commit**

```bash
git add app/models/diff_responses app/views/specs/_responses.html.erb \
        app/views/endpoints/_endpoint_diff.html.erb app/views/endpoints/_endpoint_new.html.erb \
        app/views/endpoints/_endpoint_removed.html.erb spec/models/diff_responses/from_responses_spec.rb
git commit -m "Diff responses per code, reusing Diff::FromValues"
```

---

## Task 3: Consume `output` in services + test server (still additive)

`format_responses` starts persisting per-code `output`; the test server selects a response by code. Endpoint `output`/`output_error` columns and attrs are still required (dropped in Task 5).

**Files:**
- Modify: `app/services/candidate/create.rb`, `app/services/candidate/update.rb`
- Modify: `app/controllers/test_server_controller.rb`
- Modify: `spec/services/create_candidate_spec.rb`, `spec/requests/candidates_requests_spec.rb`, `spec/requests/endpoints_requests_spec.rb`
- Test: `spec/requests/test_server_requests_spec.rb` (create)

**Interfaces:**
- Consumes: `Response#parsed_output`, params shape `version[endpoints_attributes][][responses][CODE][note|output]`.
- Produces: persisted responses carrying `output`; `TestServerController#output(endpoint, request)` returning the parsed schema for the requested code (default = lowest 2xx, else lowest code).

- [ ] **Step 1: Write the failing test-server spec**

Create `spec/requests/test_server_requests_spec.rb`:

```ruby
require "rails_helper"

describe "Test server", type: :request do
  let(:group) { FactoryBot.create(:group) }
  let(:project) { FactoryBot.create(:project, group: group, name: "proj") }
  let(:version) { FactoryBot.create(:version, project: project, name: "v1") }
  let!(:endpoint) do
    FactoryBot.create(:endpoint, version: version, http_verb: "verb_get", path: "/users").tap do |e|
      FactoryBot.create(:response, endpoint: e, code: "200", output: "{ name: string }")
      FactoryBot.create(:response, endpoint: e, code: "404", output: "Error")
    end
  end
  let!(:error_entity) { FactoryBot.create(:entity, version: version, name: "Error", root: "{ message: string }") }

  it "returns the schema for the requested code" do
    get "/projects/proj/versions/v1/users", params: { response: "404" }
    expect(response.status).to eq(200)
    expect(response.body).to include("message")
  end

  it "defaults to the lowest 2xx response when no code is given" do
    get "/projects/proj/versions/v1/users"
    expect(response.body).to include("name")
  end

  it "raises for an unknown code" do
    expect {
      get "/projects/proj/versions/v1/users", params: { response: "999" }
    }.to raise_error(TestServerController::InvalidResponseCode)
  end
end
```

Note: confirm the route prefix `/projects/:project_name/versions/:version_name/*` matches `config/routes.rb`; adjust the path if the constraint differs.

- [ ] **Step 2: Run it; expect failure**

Run: `bundle exec rspec spec/requests/test_server_requests_spec.rb`
Expected: FAIL — controller still uses `endpoint.parsed_output`/`parsed_output_error`.

- [ ] **Step 3: Rewrite `TestServerController#output`**

In `app/controllers/test_server_controller.rb` replace the `output` method:

```ruby
  def output(endpoint, request)
    desired_response = request.params[:response]

    if desired_response.nil?
      response = default_response(endpoint)
      raise InvalidResponseCode.new("No responses defined") if response.nil?
      return response.parsed_output
    end

    response = endpoint.responses.find_by(code: desired_response)
    raise InvalidResponseCode.new("Invalid response code: #{desired_response}") if response.nil?
    response.parsed_output
  end

  def default_response(endpoint)
    responses = endpoint.responses.sort_by(&:code)
    responses.find { |r| r.code.start_with?("2") } || responses.first
  end
```

- [ ] **Step 4: Run the test-server spec; expect pass**

Run: `bundle exec rspec spec/requests/test_server_requests_spec.rb`
Expected: PASS (3 examples).

- [ ] **Step 5: Update `format_responses` in both services**

In `app/services/candidate/create.rb` AND `app/services/candidate/update.rb` replace `format_responses`:

```ruby
  def format_responses(responses_hash)
    return [] unless responses_hash
    responses_hash.to_hash.entries.map do |code, attrs|
      { code: code, note: attrs[:note].to_s, output: attrs[:output].to_s }
    end
  end
```

(Leave the endpoint `output:`/`output_error:` lines in the `endpoints_attributes` mapping untouched — the columns still require them.)

- [ ] **Step 6: Update the service/request specs to the nested response param shape**

In `spec/services/create_candidate_spec.rb`, `spec/requests/candidates_requests_spec.rb`, and `spec/requests/endpoints_requests_spec.rb`, add a `responses` key to the endpoint in `valid_params` (keep the existing `output`/`output_error` for now):

```ruby
endpoints_attributes: [
  { path: "/",
    http_verb: "verb_get",
    output: "",
    output_error: "",
    responses: { "200" => { note: "ok", output: "User" } }
  }
],
```

Add an assertion in `create_candidate_spec.rb` proving the schema persists:

```ruby
it "persists the per-response output schema" do
  subject.call
  response = Endpoint.last.responses.find_by(code: "200")
  expect(response.output).to eq("User")
  expect(response.note).to eq("ok")
end
```

- [ ] **Step 7: Run the full suite; expect pass**

Run: `bundle exec rspec`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add app/services/candidate/create.rb app/services/candidate/update.rb \
        app/controllers/test_server_controller.rb spec/services/create_candidate_spec.rb \
        spec/requests/candidates_requests_spec.rb spec/requests/endpoints_requests_spec.rb \
        spec/requests/test_server_requests_spec.rb
git commit -m "Persist and serve per-response output schemas"
```

---

## Task 4: React form — one schema editor per response

No JS test framework exists, so verification is `bin/vite build` + lint + a manual smoke note. This task also flips `Version#existing_endpoints_for_frontend` to the new payload (frontend-only; not RSpec-covered).

**Files:**
- Modify: `app/models/version.rb`
- Modify: `app/javascript/components/EndpointAdded.jsx`, `EndpointDiff.jsx`, `EndpointRemoved.jsx`, `Form.jsx`

**Interfaces:**
- Consumes: `JSONSchemaForm` (`root`, `name`, `update`, `id`, `entities`), `StaticJSONSchema` (`root`), `serialize`/`deserialize` helpers.
- Produces: form posts `version[endpoints_attributes][][responses][CODE][note]` and `[CODE][output]` (consumed by Task 3's `format_responses`); each response object in React carries `{ code, note, output }` where `output` is a deserialized schema node.

- [ ] **Step 1: Update the frontend payload**

In `app/models/version.rb`, replace `existing_endpoints_for_frontend`:

```ruby
  def existing_endpoints_for_frontend
    endpoints.map do |endpoint|
      {
        http_verb: endpoint.http_verb,
        verb: endpoint.verb,
        path: endpoint.path,
        note: endpoint.note,
        responses: endpoint.responses.sort_by(&:code).map { |r| { code: r.code, note: r.note, output: r.output } }
      }
    end.to_json
  end
```

- [ ] **Step 2: `EndpointAdded.jsx` — per-response editor**

In `app/javascript/components/EndpointAdded.jsx`:

Remove `updateOutput` and `updateOutputError`. Change `addResponse` to seed an output, and add `updateResponseOutput`:

```jsx
    const addResponse = () => {
        const newResponses = [...endpoint.responses, {code: newResponseCode, note: "", output: {nodeType: "primitive", value: "nothing"}}]
        updateEndpoint(endpoint.id, {...endpoint, responses: newResponses})
    }

    const updateResponseNote = (code, newNote) => {
        const index = endpoint.responses.findIndex((r) => r.code === code)
        const r = endpoint.responses[index]
        const newResponses = [
            ...endpoint.responses.slice(0, index),
            {...r, note: newNote},
            ...endpoint.responses.slice(index + 1),
        ]
        updateEndpoint(endpoint.id, {...endpoint, responses: newResponses})
    }

    const updateResponseOutput = (code, newOutput) => {
        const index = endpoint.responses.findIndex((r) => r.code === code)
        const r = endpoint.responses[index]
        const newResponses = [
            ...endpoint.responses.slice(0, index),
            {...r, output: newOutput},
            ...endpoint.responses.slice(index + 1),
        ]
        updateEndpoint(endpoint.id, {...endpoint, responses: newResponses})
    }
```

Replace the whole `Responses` section AND delete the two `Output` / `Output for Errors` sections, so each response renders its note input, a remove button, and a `JSONSchemaForm`:

```jsx
                    <div className={sectionHeader}>Responses</div>
                    <div className="pl-2 py-2 bg-emerald-50 border-b border-emerald-200 space-y-3">
                        {endpoint.responses.map((r) => (
                            <div key={r.code} className="border border-emerald-200 rounded bg-white p-2">
                                <div className="flex items-center gap-2">
                                    <span className="font-mono text-xs text-gray-500 shrink-0">{r.code}:</span>
                                    <input
                                        type="text"
                                        value={r.note}
                                        onChange={(e) => updateResponseNote(r.code, e.target.value)}
                                        className="border border-gray-300 rounded px-2 py-0.5 text-xs flex-1 focus:outline-none focus:ring-1 focus:ring-emerald-500 bg-white"
                                    />
                                    <button type="button" onClick={() => removeResponse(r.code)} className="text-xs text-red-500 hover:text-red-700 shrink-0">×</button>
                                    <input type="hidden" name={`version[endpoints_attributes][][responses][${r.code}][note]`} value={r.note}/>
                                </div>
                                <div className="pl-2 pt-2">
                                    <JSONSchemaForm
                                        name={`version[endpoints_attributes][][responses][${r.code}][output]`}
                                        update={(newOutput) => updateResponseOutput(r.code, newOutput)}
                                        root={r.output}
                                        id={`${endpoint.id}-${r.code}`}
                                        entities={entities}
                                    />
                                </div>
                            </div>
                        ))}
                        <div className="flex items-center gap-2 pt-1">
                            <select
                                value={newResponseCode ?? ""}
                                onChange={(e) => setNewResponseCode(e.target.value)}
                                className="border border-gray-300 rounded text-xs px-1 py-0.5 focus:outline-none focus:ring-1 focus:ring-emerald-500 bg-white"
                            >
                                {responsesToAdd.map((r) => (<option key={r} value={r}>{r}</option>))}
                            </select>
                            <button type="button" onClick={() => addResponse()} className="text-xs bg-emerald-600 hover:bg-emerald-700 text-white px-2 py-0.5 rounded">Add</button>
                        </div>
                    </div>
```

- [ ] **Step 3: `EndpointDiff.jsx` — same per-response editor (right column) + read-only left column**

Apply the identical `addResponse` / `updateResponseNote` / `updateResponseOutput` handler changes as Step 2 (remove `updateOutput`/`updateOutputError`).

Replace the right-column Responses section and delete its two Output sections, using the same JSX as Step 2 but with sky colors (`border-gray-300`, `focus:ring-sky-500`, `bg-sky-600 hover:bg-sky-700` for the Add button, and a `border-gray-200` wrapper per response).

Replace the left read-only column's Responses block and delete its two Output sections so each original response shows its schema:

```jsx
                <div className={sectionHeader}>Responses</div>
                <div className={contentRowPl}>
                    {endpoint.original_responses.length === 0
                        ? <span className="text-xs text-gray-400 italic">—</span>
                        : endpoint.original_responses.map((r) => (
                            <div key={r.code} className="border border-gray-200 rounded bg-white p-2 mb-2">
                                <div className="text-sm text-gray-700">
                                    <span className="font-mono text-gray-500">{r.code}</span>{r.note ? `: ${r.note}` : ""}
                                </div>
                                <div className="pl-2 pt-1"><StaticJSONSchema root={r.output}/></div>
                            </div>
                        ))
                    }
                </div>
```

- [ ] **Step 4: `EndpointRemoved.jsx` — read-only responses with schema, drop Output sections**

In `app/javascript/components/EndpointRemoved.jsx`, replace the Responses block (same JSX as the left column in Step 3) and delete the two Output sections that referenced `endpoint.output` / `endpoint.output_error`.

- [ ] **Step 5: `Form.jsx` — scan response outputs for entity references**

Replace `findCustomNameInEndpoints`:

```jsx
const findCustomNameInEndpoints = (endpoints, name) => {
    let found = false;
    endpoints.forEach((e) => {
        e.responses.forEach((r) => {
            found = found || findCustomName(r.output, name)
        })
    })
    return found
}
```

- [ ] **Step 6: `Form.jsx` — submit serialization (and change detection)**

In the serialization block (currently building `serializedEndpointsToSend`), drop `output`/`output_error` and serialize each response's output:

```jsx
        const serializedEndpointsToSend = JSON.stringify(endpointsToSend
            .filter((endpoint) => (endpoint.type !== 'removed'))
            .map((endpoint) => ({
                http_verb: endpoint.http_verb,
                verb: endpoint.verb,
                path: endpoint.path,
                note: endpoint.note,
                responses: [...endpoint.responses]
                    .sort((a, b) => Number(a.code) - Number(b.code))
                    .map((r) => ({code: r.code, note: r.note, output: serialize(r.output)})),
            })))
```

- [ ] **Step 7: `Form.jsx` — load: deserialize each response output into two independent deep copies**

In the load `useEffect`, replace the per-endpoint output handling. Remove the `parsed_output` / `original_output` / `parsed_output_error` / `original_output_error` lines and replace with deserialized response copies:

```jsx
            endpointData.type = "old"
            endpointData.id = uuidv4()
            endpointData.collision = false

            endpointData.original_path = endpointData.path
            endpointData.original_verb = endpointData.verb
            endpointData.original_http_verb = endpointData.http_verb
            endpointData.original_note = endpointData.note

            const editable = endpointData.responses.map((r) => ({code: r.code, note: r.note, output: deserialize(r.output)}))
            const original = endpointData.responses.map((r) => ({code: r.code, note: r.note, output: deserialize(r.output)}))
            endpointData.responses = editable
            endpointData.original_responses = original
```

(The two `.map` calls build separate node trees, so editing the right column never mutates the read-only left column.)

- [ ] **Step 8: `Form.jsx` — addEndpoint default and restore**

In `addEndpoint`, drop `output`/`output_error` (keep `responses: []`):

```jsx
        newEndpoints.push({
            id: uuidv4(),
            type: "new",
            http_verb: newVerb,
            verb: newVerb,
            path: newPath,
            responses: []
        })
```

In `restoreEndpoint`, remove the `output`/`output_error` restore lines and deep-clone the original responses back:

```jsx
        endpointToRestore.note = endpointToRestore.original_note
        endpointToRestore.responses = JSON.parse(JSON.stringify(endpointToRestore.original_responses))
        endpointToRestore.collision = false
```

- [ ] **Step 9: `Form.jsx` — require ≥ 1 response (soft validation)**

In `validate`, after the collision loop, also flag endpoints with no responses and fold into `noCollisions` so Save is disabled. Inside the existing `forEach` over non-removed endpoints add:

```jsx
                if (endpoint.responses.length === 0) {
                    newNoCollisions = false;
                    endpoint.no_responses = true;
                } else {
                    endpoint.no_responses = false;
                }
```

In `EndpointAdded.jsx` and `EndpointDiff.jsx` headers, surface it next to the collision indicator:

```jsx
                        {endpoint.no_responses && <span className="text-xs text-red-300">Needs a response</span>}
```

- [ ] **Step 10: Build and lint**

Run: `bin/vite build`
Expected: build succeeds, no unresolved imports/refs.
Run: `bin/rubocop`
Expected: clean (Ruby files from Step 1).

- [ ] **Step 11: Manual smoke (note in commit, not automated)**

With `bin/dev` running: open a candidate form, add an endpoint, add a response, confirm a schema editor appears under it; edit the schema and Save; reopen and confirm it round-trips; remove an endpoint and "Bring back" and confirm the schema returns unmutated.

- [ ] **Step 12: Commit**

```bash
git add app/models/version.rb app/javascript/components/EndpointAdded.jsx \
        app/javascript/components/EndpointDiff.jsx app/javascript/components/EndpointRemoved.jsx \
        app/javascript/components/Form.jsx
git commit -m "Edit a schema per response in the candidate form"
```

---

## Task 5: Drop endpoint `output`/`output_error` (the breaking cut-over)

Everything now reads response schemas, so the endpoint columns and their last references can go.

**Files:**
- Modify: `db/migrate/20250219083627_create_endpoints.rb`
- Modify: `app/models/endpoint.rb`
- Modify: `app/services/candidate/create.rb`, `app/services/candidate/update.rb`
- Modify: `app/views/endpoints/_endpoint_diff.html.erb`, `_endpoint_new.html.erb`, `_endpoint_removed.html.erb`
- Modify: `spec/factories/endpoints.rb`
- Modify: `test/fixtures/endpoints.yml`
- Modify: `spec/services/create_candidate_spec.rb`, `spec/requests/candidates_requests_spec.rb`, `spec/requests/endpoints_requests_spec.rb`, `spec/models/endpoint_spec.rb`

**Interfaces:**
- Consumes: `DiffResponses::FromResponses#any_changes?`, `DiffText::FromNotes`.
- Produces: `Endpoint` with no `output`/`output_error`; `differs_from?` based only on note + responses.

- [ ] **Step 1: Update `endpoint_spec.rb` for the new `differs_from?`**

In `spec/models/endpoint_spec.rb`, ensure there are examples covering: equal endpoints (no change), a note change, and a response schema/code change — building endpoints via responses, not `output`. Add if missing:

```ruby
it "differs when a response schema changes" do
  e1 = FactoryBot.create(:endpoint, version: version, path: "/x", http_verb: "verb_get")
  FactoryBot.create(:response, endpoint: e1, code: "200", output: "string")
  e2 = FactoryBot.create(:endpoint, version: version2, path: "/x", http_verb: "verb_get")
  FactoryBot.create(:response, endpoint: e2, code: "200", output: "number")
  expect(e2.differs_from?(e1)).to be(true)
end
```

(Use whatever `version`/`version2` setup the existing spec already defines; mirror it.)

- [ ] **Step 2: Run it; expect failure (or error on removed columns later)**

Run: `bundle exec rspec spec/models/endpoint_spec.rb`
Expected: new example may pass already (Task 2 wired responses into `differs_from?`); proceed to make the column-drop changes which this step guards.

- [ ] **Step 3: Drop the columns (edit migration in place)**

In `db/migrate/20250219083627_create_endpoints.rb` remove the `output` and `output_error` lines:

```ruby
class CreateEndpoints < ActiveRecord::Migration[8.0]
  def change
    create_table :endpoints do |t|
      t.integer :http_verb, null: false
      t.string :path, null: false
      t.references :version, null: false, foreign_key: true
      t.string :note, null: true

      t.timestamps
    end
  end
end
```

- [ ] **Step 4: Rebuild the test schema**

Run: `bin/rails db:migrate:reset RAILS_ENV=test`
Expected: `db/schema.rb` no longer lists `endpoints.output`/`output_error`.

- [ ] **Step 5: Simplify `Endpoint`**

In `app/models/endpoint.rb` delete `parsed_output` and `parsed_output_error`, and replace `differs_from?`:

```ruby
  def differs_from?(previous)
    DiffText::FromNotes.new(previous.note, note).any_changes? ||
      DiffResponses::FromResponses.new(previous.responses, responses).any_changes?
  end
```

- [ ] **Step 6: Remove endpoint outputs from the services**

In `app/services/candidate/create.rb` and `update.rb`, delete the `output:` and `output_error:` keys from the `endpoints_attributes` mapping (leave `responses_attributes`).

- [ ] **Step 7: Remove the Output sections from the three views**

In `_endpoint_diff.html.erb`, `_endpoint_new.html.erb`, `_endpoint_removed.html.erb`:
- Delete the `<% output... %>` / `output_diff` / `output_error_diff` ERB setup lines.
- Delete both "Output" and "Output for Errors" `sectionHeader` + render blocks.
- Replace the expand-button condition `endpoint.parsed_output.expandable? || endpoint.parsed_output_error.expandable?` with `endpoint.responses.any? { |r| r.parsed_output.expandable? }` (and in the diff view's pair, use the relevant endpoint on each side).

- [ ] **Step 8: Update the endpoint factory**

`spec/factories/endpoints.rb`:

```ruby
FactoryBot.define do
  factory :endpoint do
    http_verb { "verb_get" }
    path { "/resource" }
    association :version
  end
end
```

- [ ] **Step 9: Update the endpoint fixtures**

In `test/fixtures/endpoints.yml`, delete every `output:` and `output_error:` line (the schemas now live in `responses.yml`).

- [ ] **Step 10: Remove endpoint outputs from the remaining specs**

In `spec/services/create_candidate_spec.rb`, `spec/requests/candidates_requests_spec.rb`, `spec/requests/endpoints_requests_spec.rb`, delete the `output: ""` / `output_error: ""` keys from `valid_params` endpoint hashes (keep the `responses` key added in Task 3).

- [ ] **Step 11: Run the full suite**

Run: `bundle exec rspec`
Expected: PASS.

- [ ] **Step 12: Lint + verify dev DB rebuild**

Run: `bin/rubocop`
Expected: clean.
Run: `bin/rails dev:setup`
Expected: completes; fixtures load with no missing-column errors.

- [ ] **Step 13: Commit**

```bash
git add -A
git commit -m "Drop endpoint output/output_error in favor of per-response schemas"
```

---

## Self-Review

**Spec coverage:**
- responses.output column + Response#parsed_output → Task 1. ✓
- Drop endpoint output/output_error → Task 5. ✓
- DiffResponses gutted to orchestrator, Line deleted, ResponseDiff with note_diff/output_diff/state, nothing-substitution, any_changes? → Task 2. ✓
- Endpoint#differs_from? simplified → Task 5 (interim correct in Task 2). ✓
- format_responses {code,note,output} → Task 3. ✓
- Version#existing_endpoints_for_frontend → Task 4. ✓
- TestServerController by-code + default (lowest 2xx, else lowest) + unknown raises → Task 3. ✓
- Form params shape responses[CODE][note|output] → Task 3 (consumer) + Task 4 (producer). ✓
- React per-code blocks, addResponse seeds nothing, updateResponseOutput, findCustomName over responses, deep-clone load + restore, anyChanges includes outputs, ≥1 response validation, codes immutable → Task 4. ✓
- ERB per-code blocks with state colors, remove Output sections, expand condition → Task 2 (blocks) + Task 5 (removal/expand). ✓
- Fixtures (responses populated, endpoints stripped) → Task 1 + Task 5. ✓
- Tests: Response#parsed_output, DiffResponses, Create/Update, TestServer, differs_from? → Tasks 1–3, 5. ✓
- No system tests. ✓

**Placeholder scan:** No TBD/"handle edge cases"/vague steps; fixture bulk handled by an explicit deterministic rule + a fully worked v1 block.

**Type consistency:** `parsed_output` (Response), `DiffResponses::FromResponses#lines`, `ResponseDiff#{code,state,note_diff,output_diff,before_present?,after_present?}`, partial locals `lines:`/`side:`, param keys `responses[CODE][note|output]`, React `{code,note,output}` are used consistently across tasks.

**Interim-state note:** Between Task 2 and Task 5 the views show both the new per-code schema blocks and the legacy Output sections; this is intentional and disappears in Task 5.
