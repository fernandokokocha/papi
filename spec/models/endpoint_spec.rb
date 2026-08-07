require "rails_helper"

describe Endpoint, "#differs_from?" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }
  let!(:v1) { FactoryBot.create(:version, project: project, name: "v1") }
  let!(:v2) { FactoryBot.create(:version, project: project, name: "v2") }

  it "reports no difference when endpoints are identical" do
    e1 = FactoryBot.create(:endpoint, version: v1, path: "/x", http_verb: "verb_get", note: "hello")
    FactoryBot.create(:response, endpoint: e1, code: "200", output: "string")
    e2 = FactoryBot.create(:endpoint, version: v2, path: "/x", http_verb: "verb_get", note: "hello")
    FactoryBot.create(:response, endpoint: e2, code: "200", output: "string")
    expect(e2.differs_from?(e1)).to be(false)
  end

  it "differs when a note changes" do
    e1 = FactoryBot.create(:endpoint, version: v1, path: "/x", http_verb: "verb_get", note: "old note")
    e2 = FactoryBot.create(:endpoint, version: v2, path: "/x", http_verb: "verb_get", note: "new note")
    expect(e2.differs_from?(e1)).to be(true)
  end

  it "differs when a response schema changes" do
    e1 = FactoryBot.create(:endpoint, version: v1, path: "/x", http_verb: "verb_get")
    FactoryBot.create(:response, endpoint: e1, code: "200", output: "string")
    e2 = FactoryBot.create(:endpoint, version: v2, path: "/x", http_verb: "verb_get")
    FactoryBot.create(:response, endpoint: e2, code: "200", output: "number")
    expect(e2.differs_from?(e1)).to be(true)
  end

  it "differs when an input schema changes" do
    e1 = FactoryBot.create(:endpoint, version: v1, path: "/x", http_verb: "verb_post", input: "{a:string}")
    e2 = FactoryBot.create(:endpoint, version: v2, path: "/x", http_verb: "verb_post", input: "{a:number}")
    expect(e2.differs_from?(e1)).to be(true)
  end

  it "differs when an input is added" do
    e1 = FactoryBot.create(:endpoint, version: v1, path: "/x", http_verb: "verb_post")
    e2 = FactoryBot.create(:endpoint, version: v2, path: "/x", http_verb: "verb_post", input: "{a:string}")
    expect(e2.differs_from?(e1)).to be(true)
  end
end

describe Endpoint, "#parsed_input" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }
  let!(:version) { FactoryBot.create(:version, project: project, name: "v1") }

  it "is nothing when the endpoint takes no request body" do
    endpoint = FactoryBot.create(:endpoint, version: version)
    expect(endpoint.parsed_input).to eq(Node::Nothing.new)
  end

  it "parses the schema like any other value" do
    endpoint = FactoryBot.create(:endpoint, version: version, input: "[string]")
    expect(endpoint.parsed_input).to eq(Node::Array.new(value: Node::Primitive.new(kind: "string")))
  end

  it "resolves entity references against its own version" do
    entity = FactoryBot.create(:entity, version: version, name: "User", root: "{id:number}")
    endpoint = FactoryBot.create(:endpoint, version: version, input: "User")
    expect(endpoint.parsed_input).to eq(Node::Entity.new(entity: entity))
  end

  it "expands entity references on request" do
    FactoryBot.create(:entity, version: version, name: "User", root: "{id:number}")
    endpoint = FactoryBot.create(:endpoint, version: version, input: "User")

    expect(endpoint.parsed_input(expanded: true))
      .to eq(Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "id", value: Node::Primitive.new(kind: "number"))
      ]))
  end
end
