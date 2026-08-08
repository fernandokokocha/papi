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

  it "differs when a param is renamed" do
    e1 = FactoryBot.create(:endpoint, version: v1, path: "/user/:id")
    e2 = FactoryBot.create(:endpoint, version: v2, path: "/user/:user_id")
    expect(e2.differs_from?(e1)).to be(true)
  end

  it "differs when a param kind changes" do
    e1 = FactoryBot.create(:endpoint, version: v1, path: "/x/:id")
    FactoryBot.create(:endpoint_param, endpoint: e1, name: "id", kind: "string")
    e2 = FactoryBot.create(:endpoint, version: v2, path: "/x/:id")
    FactoryBot.create(:endpoint_param, endpoint: e2, name: "id", kind: "number")
    expect(e2.differs_from?(e1)).to be(true)
  end

  it "reports no difference when params match" do
    e1 = FactoryBot.create(:endpoint, version: v1, path: "/x/:id")
    FactoryBot.create(:endpoint_param, endpoint: e1, name: "id", kind: "number")
    e2 = FactoryBot.create(:endpoint, version: v2, path: "/x/:id")
    FactoryBot.create(:endpoint_param, endpoint: e2, name: "id", kind: "number")
    expect(e2.differs_from?(e1)).to be(false)
  end
end

describe Endpoint, "#param_names" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }
  let!(:version) { FactoryBot.create(:version, project: project, name: "v1") }

  it "is empty when the path has no params" do
    endpoint = FactoryBot.build(:endpoint, version: version, path: "/users/me")
    expect(endpoint.param_names).to eq([])
  end

  it "reads the colon-prefixed tokens in path order" do
    endpoint = FactoryBot.build(:endpoint, version: version, path: "/post/:postId/revisions/:slug")
    expect(endpoint.param_names).to eq([ "postId", "slug" ])
  end

  it "stops a token at a slash" do
    endpoint = FactoryBot.build(:endpoint, version: version, path: "/post/:postId/revisions")
    expect(endpoint.param_names).to eq([ "postId" ])
  end
end

describe Endpoint, "#identity_name" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }
  let!(:version) { FactoryBot.create(:version, project: project, name: "v1") }

  def endpoint(path, verb: "verb_get")
    FactoryBot.build(:endpoint, version: version, path: path, http_verb: verb)
  end

  it "erases param names, which are ours rather than the client's" do
    expect(endpoint("/user/:id").identity_name).to eq(endpoint("/user/:user_id").identity_name)
  end

  it "keeps paths with different literal segments apart" do
    expect(endpoint("/user/:id").identity_name).not_to eq(endpoint("/account/:id").identity_name)
  end

  it "keeps the same path under different verbs apart" do
    expect(endpoint("/user/:id").identity_name).not_to eq(endpoint("/user/:id", verb: "verb_post").identity_name)
  end

  it "counts how many params the path takes" do
    expect(endpoint("/user/:id/post/:postId").identity_name).not_to eq(endpoint("/user/:id/post").identity_name)
  end

  it "leaves a path with no params alone" do
    expect(endpoint("/users/me").identity_name).to eq("GET /users/me")
  end
end

describe Endpoint, "#path_params" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }
  let!(:version) { FactoryBot.create(:version, project: project, name: "v1") }

  it "follows the path, not the order the rows were stored in" do
    endpoint = FactoryBot.create(:endpoint, version: version, path: "/tasks/:taskId/comments/:commentId")
    FactoryBot.create(:endpoint_param, endpoint: endpoint, name: "commentId", kind: "number")
    FactoryBot.create(:endpoint_param, endpoint: endpoint, name: "taskId", kind: "number")

    expect(endpoint.path_params.map(&:name)).to eq([ "taskId", "commentId" ])
  end

  it "defaults a param with no stored kind to string" do
    endpoint = FactoryBot.create(:endpoint, version: version, path: "/tasks/:taskId")

    expect(endpoint.path_params.map(&:kind)).to eq([ "string" ])
  end

  it "ignores a stored param the path no longer mentions" do
    endpoint = FactoryBot.create(:endpoint, version: version, path: "/tasks")
    FactoryBot.create(:endpoint_param, endpoint: endpoint, name: "taskId", kind: "number")

    expect(endpoint.path_params).to eq([])
  end
end

describe Endpoint, "path param uniqueness" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }
  let!(:version) { FactoryBot.create(:version, project: project, name: "v1") }

  it "accepts distinct params" do
    endpoint = FactoryBot.build(:endpoint, version: version, path: "/posts/:postId/comments/:commentId")
    expect(endpoint).to be_valid
  end

  it "rejects a param repeated in the path" do
    endpoint = FactoryBot.build(:endpoint, version: version, path: "/posts/:id/comments/:id")

    expect(endpoint).not_to be_valid
    expect(endpoint.errors[:path]).to eq([ "repeats :id" ])
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
    expect(endpoint.reload.parsed_input).to eq(Node::Entity.new(entity: entity))
  end

  it "expands entity references on request" do
    FactoryBot.create(:entity, version: version, name: "User", root: "{id:number}")
    endpoint = FactoryBot.create(:endpoint, version: version, input: "User")

    expect(endpoint.reload.parsed_input(expanded: true))
      .to eq(Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "id", value: Node::Primitive.new(kind: "number"))
      ]))
  end
end
