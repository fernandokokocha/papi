require "rails_helper"

describe "Candidate form requests", type: :request do
  let!(:group) { Group.create!(name: "Test group") }
  let!(:user) { User.create!(email_address: "test@example.com", password: "password", group: group) }
  let!(:project) { Project.create!(name: "project", group: group) }

  let!(:base_candidate) { FactoryBot.create(:candidate, name: "rc1", project: project, decided_by: user, aasm_state: "merged") }
  let!(:base_version) { FactoryBot.create(:version, project: project, candidate: base_candidate, name: "v1", order: 1) }
  let!(:customer) { FactoryBot.create(:entity, version: base_version, name: "Customer", root: "{id:number,name:string}") }
  let!(:order) { FactoryBot.create(:entity, version: base_version, name: "Order", root: "{customer:Customer,total:number}") }
  let!(:user_token) { FactoryBot.create(:auth_method, version: base_version, name: "UserToken", kind: "bearer", note: "A token from POST /session.") }
  let!(:endpoint) { FactoryBot.create(:endpoint, version: base_version, path: "/customers/:id", auth: "UserToken", note: "One customer.", input: "") }
  let!(:path_param) { FactoryBot.create(:endpoint_param, endpoint: endpoint, name: "id", kind: "number") }
  let!(:query_param) { FactoryBot.create(:endpoint_param, :query, endpoint: endpoint, name: "expand", kind: "boolean", required: false) }
  let!(:ok) { FactoryBot.create(:response, endpoint: endpoint, code: "200", note: "The customer.", output: "Customer") }
  let!(:missing) { FactoryBot.create(:response, endpoint: endpoint, code: "404", note: "No such customer.", output: "") }

  before { sign_in(user) }

  def form
    get new_project_candidate_path(project.name)
    Nokogiri::HTML5.fragment(response.body)
  end

def with_forgery_protection
  original = ActionController::Base.allow_forgery_protection
  ActionController::Base.allow_forgery_protection = true
  yield
ensure
  ActionController::Base.allow_forgery_protection = original
end

  it "renders each entity's schema as an editable block, named for the params the create service reads" do
    fields = form.css("input[type=hidden]").to_h { |input| [ input["name"], input["value"] ] }

    expect(fields["version[entities_attributes][0][name]"]).to eq("Customer")
    expect(fields["version[entities_attributes][0][root]"]).to eq("{id:number,name:string}")
    expect(fields["version[entities_attributes][1][name]"]).to eq("Order")
    expect(fields["version[entities_attributes][1][root]"]).to eq("{customer:Customer,total:number}")
  end

  it "numbers the editor's rows the way the diff numbers its lines" do
    rendered = form.css("#entity_root_0 .w-8").map(&:text).reject(&:blank?)
    lines = customer.parsed_root.to_diff(:no_change).lines

    expect(rendered).to eq((1..lines.size).map(&:to_s))
  end

  # Order already names Customer, so Customer may not name Order back, and
  # neither may name itself.
  it "offers only the entities a block can name without closing a circle" do
    page = form
    types = ->(id) { page.css("##{id} select").flat_map { |select| select.css("option").map(&:text) }.uniq }

    expect(types.("entity_root_1")).to include("Customer")
    expect(types.("entity_root_1")).not_to include("Order")
    expect(types.("entity_root_0")).not_to include("Customer", "Order")
  end

  # The whole point of building it in place: what the editor renders is what the
  # create service already reads, so a candidate really is created from it.
  it "creates a candidate whose entity carries the edited schema" do
    post project_candidates_path(project.name), params: {
      candidate: { project_id: project.id, name: "rc2" },
      version: {
        name: "rc2-v1", order: 1,
        endpoints_attributes: [ { path: "/", http_verb: "verb_get", input: "", responses: { "200" => { note: "ok", output: "Customer" } } } ],
        entities_attributes: {
          "0" => { name: "Customer", root: "{id:number,name:string,vip:boolean}" },
          "1" => { name: "Order", root: "{customer:Customer,total:number}" }
        }
      }
    }

    expect(response).to redirect_to(project_candidate_path(project.name, "rc2"))
    expect(Version.last.entities.find_by(name: "Customer").root).to eq("{id:number,name:string,vip:boolean}")
  end

  # Turbo Drive is off, so an op is only intercepted when both the form it
  # belongs to and the element that submits it opt in. Miss either and the
  # browser navigates to the raw stream.
  it "puts the editor's controls in a Turbo form of their own" do
    page = form
    ops = page.at_css("form##{SchemaForm::OPS_FORM_ID}")

    expect(ops["data-turbo"]).to eq("true")
    expect(ops["action"]).to eq(schema_edit_path)
    expect(page.at_css("#entity_root_0")["data-turbo"]).to eq("true")

    controls = page.css("#entity_root_0 button[type=submit], #entity_root_0 select, #entity_root_0 input:not([type=hidden])")
    expect(controls).to be_any
    expect(controls.map { |control| control["form"] }.uniq).to eq([ SchemaForm::OPS_FORM_ID ])
  end

  # A card is asked for in the bar menu or on the sidebar section it belongs to,
  # and both hosts write into the one ops form, so every field starts closed and
  # disabled and only the one being filled in submits.
  it "offers the three new-card fields in the bar menu and on every sidebar section" do
    page = form

    expect(page.css("[data-new-form-host-value]").map { |host| host["data-new-form-host-value"] })
      .to match_array(%w[menu endpoints_nav entities_nav auth_methods_nav])

    fields = page.css("[data-new-form-target=field]")
    expect(fields.map { |field| field["data-kind"] }).to match_array(%w[endpoint entity auth] * 2)
    expect(fields).to all(satisfy { |field| field["class"].include?("hidden") })
    expect(fields.css("input, select, button[type=submit]")).to all(satisfy { |control| control["disabled"] })
  end

  # Turbo Drive is off, so a submitter outside a data-turbo="true" container
  # navigates the browser to the stream instead of applying it.
  it "puts the new-card submitters inside a Turbo container of their own" do
    submitters = form.css("[data-new-form-target=field] button[type=submit]")

    expect(submitters.map { |button| button["formaction"] }).to all(include("asked_by="))
    expect(submitters).to all(satisfy { |button| button.ancestors("[data-turbo='true']").any? })
  end

  it "renders each endpoint's verb, path, params, query, auth and note as fields the create service reads" do
    fields = form.css("input[type=hidden]").to_h { |input| [ input["name"], input["value"] ] }

    expect(fields["version[endpoints_attributes][][http_verb]"]).to eq("verb_get")
    expect(fields["version[endpoints_attributes][][path]"]).to eq("/customers/:id")
    expect(fields["version[endpoints_attributes][][params][id][kind]"]).to eq("number")
    expect(fields["version[endpoints_attributes][][query_params][expand][kind]"]).to eq("boolean")
    expect(fields["version[endpoints_attributes][][query_params][expand][required]"]).to eq("false")
    expect(fields["version[endpoints_attributes][][auth]"]).to eq("UserToken")
    expect(fields["version[endpoints_attributes][][note]"]).to eq("One customer.")
  end

  it "renders each response as a block of its own, named for the params the create service reads" do
    fields = form.css("input[type=hidden]").to_h { |input| [ input["name"], input["value"] ] }

    expect(fields["version[endpoints_attributes][][input]"]).to eq("")
    expect(fields["version[endpoints_attributes][][responses][200][note]"]).to eq("The customer.")
    expect(fields["version[endpoints_attributes][][responses][200][output]"]).to eq("Customer")
    expect(fields["version[endpoints_attributes][][responses][404][note]"]).to eq("No such customer.")
    expect(fields["version[endpoints_attributes][][responses][404][output]"]).to eq("")
  end

  # An input and an output are the only roots that may be absent, and an entity
  # is not one of them.
  it "offers nothing at an input's and an output's root, and to no entity" do
    page = form
    types = ->(id) { page.css("##{id} select").flat_map { |select| select.css("option").map(&:text) }.uniq }

    expect(types.("endpoint_input_0")).to include("nothing")
    expect(types.("endpoint_output_0_404")).to include("nothing")
    expect(types.("entity_root_0")).not_to include("nothing")
  end

  it "puts the verb, the kinds, the query names, the auth and the note in the ops form" do
    page = form

    expect(page.at_css("select[name='endpoints[0][http_verb]'] option[selected]").text).to eq("GET")
    expect(page.at_css("select[name='endpoints[0][params][id]'] option[selected]").text).to eq("number")
    expect(page.at_css("input[name='endpoints[0][query_params][0][name]']")["value"]).to eq("expand")
    expect(page.at_css("select[name='endpoints[0][query_params][0][kind]'] option[selected]").text).to eq("boolean")
    expect(page.at_css("select[name='endpoints[0][auth]'] option[selected]").text).to eq("UserToken")
    expect(page.at_css("textarea[name='endpoints[0][note]']").text).to eq("One customer.")
  end

  it "renders each auth method's kind and note as fields the create service reads" do
    page = form
    fields = page.css("input[type=hidden]").to_h { |input| [ input["name"], input["value"] ] }

    expect(fields["version[auth_methods_attributes][0][name]"]).to eq("UserToken")
    expect(fields["version[auth_methods_attributes][0][kind]"]).to eq("bearer")
    expect(fields["version[auth_methods_attributes][0][note]"]).to eq("A token from POST /session.")

    expect(page.at_css("select[name='auth_methods[0][kind]']").css("option").map(&:text)).to eq(AuthMethod::KINDS)
    expect(page.at_css("textarea[name='auth_methods[0][note]']").text).to eq("A token from POST /session.")
  end

  it "answers an auth edit with the kind and note the whole form is holding" do
    post schema_edit_path, params: {
      op: "auth",
      auth_methods: { "0" => { name: "UserToken", kind: "basic", note: "Now a username and password." } }
    }

    page = Nokogiri::HTML5.fragment(response.body)
    expect(page.at_css("input[name='version[auth_methods_attributes][0][kind]']")["value"]).to eq("basic")
    expect(page.at_css("input[name='version[auth_methods_attributes][0][note]']")["value"]).to eq("Now a username and password.")
    expect(page.at_css("select[name='auth_methods[0][kind]'] option[selected]").text).to eq("basic")
  end

  # The whole point of building it in place: what the editor renders is what the
  # create service already reads.
  it "creates a candidate whose auth method carries the edited kind and note" do
    post project_candidates_path(project.name), params: {
      candidate: { project_id: project.id, name: "rc2" },
      version: {
        name: "rc2-v1", order: 1,
        endpoints_attributes: [ { path: "/", http_verb: "verb_get", input: "", responses: { "200" => { note: "ok", output: "Customer" } } } ],
        entities_attributes: { "0" => { name: "Customer", root: "{id:number,name:string}" } },
        auth_methods_attributes: { "0" => { name: "UserToken", kind: "basic", note: "Now a username and password." } }
      }
    }

    expect(Version.last.auth_methods.find_by(name: "UserToken")).to have_attributes(kind: "basic", note: "Now a username and password.")
  end

  # Diffing a reference asks the two entities whether they differ, and a note is
  # half of that answer — so a stand-in without them makes every reference to a
  # noted entity read as a change on a form nobody has touched yet.
  it "hands a stand-in entity the notes its own record carries" do
    customer.schema_notes.create!(path: '["id"]', body: "The customer's id.")
    page = form

    expect(page.at_css("#submit_bar").text).to include("Nothing has changed yet")
    expect(page.css("aside a[href^='#form-']").map { |link| link["class"] }.join).not_to include("amber")
  end

  # A note is pinned in a schema the form has no editor for, so the only way it
  # survives the version this form cuts is by riding across as a hidden field.
  it "carries every schema note across, so a save does not drop them" do
    customer.schema_notes.create!(path: '["id"]', body: "Sequential, not a UUID.")
    endpoint.schema_notes.create!(path: "[]", body: "Nothing goes in.")
    ok.schema_notes.create!(path: '["name"]', body: "Blank for a deleted customer.")

    fields = form.css("input[type=hidden]").map { |input| [ input["name"], input["value"] ] }

    expect(fields).to include([ "version[entities_attributes][0][schema_notes_attributes][0][path]", '["id"]' ])
    expect(fields).to include([ "version[entities_attributes][0][schema_notes_attributes][0][body]", "Sequential, not a UUID." ])
    expect(fields).to include([ "version[endpoints_attributes][][schema_notes][0][body]", "Nothing goes in." ])
    expect(fields).to include([ "version[endpoints_attributes][][responses][200][schema_notes][0][path]", '["name"]' ])
    expect(fields).to include([ "version[endpoints_attributes][][responses][200][schema_notes][0][body]", "Blank for a deleted customer." ])
  end

  it "gives the created version notes of its own, on the entity, the input and the output" do
    customer.schema_notes.create!(path: '["id"]', body: "Sequential, not a UUID.")
    endpoint.schema_notes.create!(path: "[]", body: "Nothing goes in.")
    ok.schema_notes.create!(path: '["name"]', body: "Blank for a deleted customer.")

    page = form
    post project_candidates_path(project.name), params: submitted_form(page)

    cut = Version.last
    expect(cut.entities.find_by(name: "Customer").schema_notes.map(&:body)).to eq([ "Sequential, not a UUID." ])
    expect(cut.endpoints.first.schema_notes.map(&:body)).to eq([ "Nothing goes in." ])
    expect(cut.endpoints.first.responses.find_by(code: "200").schema_notes.map(&:body)).to eq([ "Blank for a deleted customer." ])
  end

  # Editing an open candidate goes through a service of its own, which rebuilds
  # the version from scratch — so the notes have to be in the form there too.
  it "keeps the notes when an open candidate is saved again" do
    customer.schema_notes.create!(path: '["id"]', body: "Sequential, not a UUID.")
    user.update!(role: 1)
    open_candidate = FactoryBot.create(:candidate, name: "rc2", project: project, base_version: base_version,
                                       order: 2, author: user)
    draft = base_version.reload.amoeba_dup
    draft.update!(name: "rc2-v1", order: 1, candidate: open_candidate)

    get edit_project_candidate_path(project.name, open_candidate.name)
    patch project_candidate_path(project.name, open_candidate.name),
          params: submitted_form(Nokogiri::HTML5.fragment(response.body))

    expect(draft.reload.entities.find_by(name: "Customer").schema_notes.map(&:body)).to eq([ "Sequential, not a UUID." ])
  end

  # The page posts what its fields hold, so the spec posts them too rather than
  # restating the version by hand.
  def submitted_form(page)
    Rack::Utils.parse_nested_query(
      page.css("form##{SchemaForm::FORM_ID} input[type=hidden][name], form##{SchemaForm::FORM_ID} textarea[name]")
        .map { |field| "#{CGI.escape(field["name"])}=#{CGI.escape(field["value"] || field.text)}" }.join("&")
    ).merge("candidate" => { "project_id" => project.id, "name" => "rc2" })
  end

  def note_op(id, note, value, blocks)
    post schema_edit_path, params: { op: "note", id: id, note: note, value: value,
                                     base_version_id: base_version.id, blocks: blocks }
    Nokogiri::HTML5.fragment(response.body)
  end

  def entity_blocks(notes = {})
    { "entity_root_0" => { field: "version[entities_attributes][0][root]",
                           notes_field: "version[entities_attributes][0][schema_notes_attributes]",
                           name: "Customer", root: "{id:number,name:string}", notes: notes } }
  end

  # An op addresses a node one way and a note another — "0" against 0, "[]"
  # against null — so the badge sends the stored key rather than the op path.
  it "offers a note badge on every node, keyed the way the note is stored" do
    keys = form.css("#entity_root_0 [data-note-edit-target=badge]")
      .map { |badge| form.at_css("##{badge["popovertarget"]} textarea")["data-schema-edit-url-value"] }
      .map { |url| CGI.parse(URI.parse(url).query).fetch("note").first }

    expect(keys).to eq([ "[]", '["id"]', '["name"]' ])
  end

  it "pins a note, rewords it, and takes it off again when the text is cleared" do
    pinned = note_op("entity_root_0", '["id"]', "Sequential, not a UUID.", entity_blocks)
    fields = ->(page) { page.css("input[type=hidden]").to_h { |input| [ input["name"], input["value"] ] } }

    expect(fields.(pinned)["version[entities_attributes][0][schema_notes_attributes][0][path]"]).to eq('["id"]')
    expect(fields.(pinned)["version[entities_attributes][0][schema_notes_attributes][0][body]"]).to eq("Sequential, not a UUID.")
    expect(fields.(pinned)["blocks[entity_root_0][notes][0][body]"]).to eq("Sequential, not a UUID.")

    held = { "0" => { path: '["id"]', body: "Sequential, not a UUID." } }
    cleared = note_op("entity_root_0", '["id"]', "", entity_blocks(held))

    expect(fields.(cleared)).not_to include("version[entities_attributes][0][schema_notes_attributes][0][path]")
    expect(fields.(cleared)).not_to include("blocks[entity_root_0][notes][0][path]")
  end

  # A note is spec content, so pinning one is a change like any other — the card
  # tints, the sidebar says so, and the submit bar opens.
  it "reads a pinned note as a change" do
    page = note_op("entity_root_0", '["id"]', "Sequential, not a UUID.", entity_blocks)

    expect(page.at_css("a[href='#form-entity-entity_root_0']")["class"]).to include("bg-amber-100")
    expect(page.at_css("#submit_bar button[type=submit]")).to be_present
  end

  # The note has nothing left to point at, so it goes with the node.
  it "drops a note whose node the next op takes away" do
    held = { "0" => { path: '["id"]', body: "Sequential, not a UUID." },
             "1" => { path: '["name"]', body: "As the customer wrote it." } }
    post schema_edit_path, params: { op: "remove", id: "entity_root_0", path: [ "id" ],
                                     base_version_id: base_version.id, blocks: entity_blocks(held) }

    fields = Nokogiri::HTML5.fragment(response.body).css("input[type=hidden]")
      .to_h { |input| [ input["name"], input["value"] ] }

    expect(fields["blocks[entity_root_0][root]"]).to eq("{name:string}")
    expect(fields["blocks[entity_root_0][notes][0][body]"]).to eq("As the customer wrote it.")
    expect(fields).not_to include("blocks[entity_root_0][notes][1][path]")
  end

  def ops_params
    {
      base_version_id: base_version.id,
      endpoints: { "0" => { http_verb: "verb_get", path: "/customers/:id", auth: "UserToken", note: "One customer.",
                            params: { "id" => "number" },
                            query_params: { "0" => { name: "expand", kind: "boolean" } },
                            responses: { "200" => { note: "The customer." }, "404" => { note: "No such customer." } } } },
      blocks: {
        "entity_root_0" => { field: "version[entities_attributes][0][root]", name: "Customer", root: "{id:number,name:string}" },
        "entity_root_1" => { field: "version[entities_attributes][1][root]", name: "Order", root: "{customer:Customer,total:number}" },
        "endpoint_input_0" => { field: "version[endpoints_attributes][][input]", root: "" },
        "endpoint_output_0_200" => { field: "version[endpoints_attributes][][responses][200][output]", root: "Customer" },
        "endpoint_output_0_404" => { field: "version[endpoints_attributes][][responses][404][output]", root: "" }
      },
      auth_methods: { "0" => { name: "UserToken", kind: "bearer", note: "A token from POST /session." } }
    }
  end

  def submit_bar(params = ops_params)
    post schema_edit_path, params: { op: "endpoint" }.merge(params)
    Nokogiri::HTML5.fragment(response.body).at_css("#submit_bar")
  end

  # The bar is pinned above the form it submits, so its button reaches the form
  # by id rather than by nesting.
  it "withholds submit until the form reads as a diff, and reaches the form by id" do
    expect(form.at_css("##{SchemaForm::FORM_ID}")).to be_present
    expect(submit_bar.text).to include("Nothing has changed yet")
    expect(submit_bar.at_css("button[type=submit]")).to be_nil

    edited = ops_params.tap { |params| params[:endpoints]["0"][:note] = "The one customer." }
    expect(submit_bar(edited).at_css("button[type=submit]")["form"]).to eq(SchemaForm::FORM_ID)
  end

  it "names what stops the form, and points at the card it came from" do
    broken = ops_params.tap do |params|
      params[:endpoints]["1"] = { http_verb: "verb_post", path: "/customers", added: "1" }
      params[:blocks]["endpoint_input_1"] = { field: "version[endpoints_attributes][][input]", root: "" }
    end
    bar = submit_bar(broken)

    expect(bar.text).to include("1 problem")
    expect(bar.at_css("a")["href"]).to eq("#form-endpoint-1")
    expect(bar.at_css("a").text.squish).to eq("POST /customers has no responses")
    expect(bar.at_css("button[type=submit]")).to be_nil
  end

  # The ops form is its own form, so it carries its own per-form CSRF token and
  # the candidate form keeps the one Rails gave it.
  it "carries a token the schema editor's action accepts" do
    token = with_forgery_protection { form }.at_css("form##{SchemaForm::OPS_FORM_ID} input[name=authenticity_token]")["value"]

    with_forgery_protection do
      post schema_edit_path, params: {
        authenticity_token: token,
        blocks: { "entity_root_0" => { field: "version[entities_attributes][0][root]", name: "Customer", root: "{id:number}" } },
        id: "entity_root_0", op: "change_type", path: [ "id" ], value: "string"
      }
    end

    expect(response.status).to eq(200)
    expect(response.body).to include("{id:string}")
  end
end
