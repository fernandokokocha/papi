require "rails_helper"

describe SchemaForm::Checks do
  let!(:group) { Group.create!(name: "Test group") }
  let!(:project) { Project.create!(name: "project", group: group) }
  let!(:candidate) { FactoryBot.create(:candidate, name: "rc1", project: project) }
  let!(:base) { FactoryBot.create(:version, project: project, candidate: candidate, name: "v1", order: 1) }
  let!(:customer) { FactoryBot.create(:entity, version: base, name: "Customer", root: "{id:number}") }
  let!(:token) { FactoryBot.create(:auth_method, version: base, name: "UserToken", kind: "bearer", note: "A token.") }
  let!(:endpoint) { FactoryBot.create(:endpoint, version: base, path: "/customers/:id", auth: "UserToken", note: "One customer.", input: "") }
  let!(:param) { FactoryBot.create(:endpoint_param, endpoint: endpoint, name: "id", kind: "number") }
  let!(:ok) { FactoryBot.create(:response, endpoint: endpoint, code: "200", note: "The customer.", output: "Customer") }

  let(:held) { Version.find(base.id) }
  let(:endpoints) { SchemaForm::Endpoints.for_version(held.endpoints, held) }
  let(:blocks) { SchemaForm::Blocks.for_version(held, held) }
  let(:auth_methods) { SchemaForm::AuthMethods.for_version(held.auth_methods, held) }

  def checks(endpoints: self.endpoints, blocks: self.blocks, auth_methods: self.auth_methods)
    described_class.new(endpoints: endpoints, blocks: blocks, auth_methods: auth_methods, base: held)
  end

  def submitted(*attributes)
    SchemaForm::Endpoints.from(attributes.each_with_index.to_h { |one, index| [ index.to_s, one ] })
  end

  def said(checks)
    checks.problems.map { |problem| "#{problem.subject} #{problem.message}" }
  end

  it "refuses a form that reads as no diff at all" do
    expect(checks.unchanged?).to be(true)
    expect(checks).not_to be_submittable
  end

  it "lets a form through as soon as one card reads as a change" do
    edited = submitted(http_verb: "verb_get", path: "/customers/:id", note: "The one customer.",
                       params: { "id" => "number" }, responses: { "200" => { note: "The customer." } })

    expect(checks(endpoints: edited).unchanged?).to be(false)
    expect(checks(endpoints: edited)).to be_submittable
  end

  it "counts a removed card as a change, and its restoration as none" do
    expect(checks(endpoints: endpoints.removing("0")).unchanged?).to be(false)
    expect(checks(endpoints: endpoints.removing("0").restoring("0")).unchanged?).to be(true)
  end

  it "names the endpoints two of which one client cannot tell apart" do
    colliding = endpoints.adding("1", "verb_get", "/customers/:customer_id")

    expect(said(checks(endpoints: colliding))).to include("GET /customers/: is declared twice")
  end

  it "names an endpoint that answers nothing" do
    expect(said(checks(endpoints: endpoints.adding("1", "verb_post", "/customers"))))
      .to include("POST /customers has no responses")
  end

  it "names a path that asks for one param name twice" do
    repeating = submitted(http_verb: "verb_get", path: "/customers/:id/orders/:id",
                          responses: { "200" => { note: "" } })

    expect(said(checks(endpoints: repeating))).to include("GET /customers/:/orders/: repeats :id in its path")
  end

  it "names a query param left blank, and one asked for twice" do
    blank = submitted(http_verb: "verb_get", path: "/customers", responses: { "200" => { note: "" } },
                      query_params: { "0" => { name: "", kind: "string" } })
    twice = submitted(http_verb: "verb_get", path: "/customers", responses: { "200" => { note: "" } },
                      query_params: { "0" => { name: "page", kind: "number" }, "1" => { name: "page", kind: "string" } })

    expect(said(checks(endpoints: blank))).to include("GET /customers has a query param with no name")
    expect(said(checks(endpoints: twice))).to include("GET /customers names the query param page twice")
  end

  # A circle hangs expansion rather than raising, so this is the same backstop
  # Version#entity_references_are_acyclic is — the editor withholds every name
  # that would close one.
  it "names entities that reference each other in a circle" do
    circular = SchemaForm::Blocks.from(
      "entity_root_0" => { field: "version[entities_attributes][0][root]", name_field: "version[entities_attributes][0][name]", name: "Customer", root: "{order:Order}" },
      "entity_root_1" => { field: "version[entities_attributes][1][root]", name_field: "version[entities_attributes][1][name]", name: "Order", root: "{customer:Customer}" }
    )

    expect(said(checks(blocks: circular))).to include("Customer → Order → Customer reference each other in a circle")
  end

  it "says nothing about an endpoint the form has removed" do
    expect(said(checks(endpoints: endpoints.adding("1", "verb_post", "/customers").removing("1")))).to be_empty
  end
end
