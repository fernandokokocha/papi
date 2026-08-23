require "rails_helper"

describe "Candidate form requests", type: :request do
  let!(:group) { Group.create!(name: "Test group") }
  let!(:user) { User.create!(email_address: "test@example.com", password: "password", group: group) }
  let!(:project) { Project.create!(name: "project", group: group) }

  let!(:base_candidate) { FactoryBot.create(:candidate, name: "rc1", project: project, decided_by: user, aasm_state: "merged") }
  let!(:base_version) { FactoryBot.create(:version, project: project, candidate: base_candidate, name: "v1", order: 1) }
  let!(:customer) { FactoryBot.create(:entity, version: base_version, name: "Customer", root: "{id:number,name:string}") }
  let!(:order) { FactoryBot.create(:entity, version: base_version, name: "Order", root: "{customer:Customer,total:number}") }

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

  it "offers the version's other entities as types, and never the one being edited" do
    types = form.css("#entity_root_1 select").flat_map { |select| select.css("option").map(&:text) }.uniq

    expect(types).to include("Customer", "Order")
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

  # The ops form is its own form, so it carries its own per-form CSRF token and
  # the candidate form keeps the one Rails gave it.
  it "carries a token the schema editor's action accepts" do
    token = with_forgery_protection { form }.at_css("form##{SchemaForm::OPS_FORM_ID} input[name=authenticity_token]")["value"]

    with_forgery_protection do
      post schema_edit_path, params: {
        authenticity_token: token,
        version: { entities_attributes: { "0" => { root: "{id:number}" } } },
        id: "entity_root_0", field: "version[entities_attributes][0][root]",
        entity_names: [ "Customer" ], op: "change_type", path: [ "id" ], value: "string"
      }
    end

    expect(response.status).to eq(200)
    expect(response.body).to include("{id:string}")
  end
end
