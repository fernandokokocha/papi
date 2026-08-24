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
