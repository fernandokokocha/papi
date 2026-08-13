require "rails_helper"

describe Version, "endpoint collisions" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }

  def version_with(*paths)
    FactoryBot.build(:version, project: project, name: "v1").tap do |version|
      paths.each { |path| version.endpoints.build(path: path, http_verb: "verb_get") }
    end
  end

  it "rejects two endpoints a client cannot tell apart" do
    version = version_with("/user/:id", "/user/:user_id")

    expect(version).not_to be_valid
    expect(version.errors[:endpoints]).to eq([ "collide: GET /user/:" ])
  end

  it "rejects two literally identical endpoints" do
    expect(version_with("/user", "/user")).not_to be_valid
  end

  it "accepts endpoints that differ in a literal segment" do
    expect(version_with("/user/:id", "/account/:id")).to be_valid
  end

  it "accepts endpoints that differ in how many params they take" do
    expect(version_with("/user/:id", "/user/:id/posts/:postId")).to be_valid
  end
end

describe Version, "entity reference circles" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }

  def version_with(roots)
    FactoryBot.build(:version, project: project, name: "v1").tap do |version|
      roots.each { |name, root| version.entities.build(name: name, root: root) }
    end
  end

  it "rejects a circle, which would otherwise hang every diff and example" do
    version = version_with("Order" => "{customer:Customer}", "Customer" => "{order:Order}")

    expect(version).not_to be_valid
    expect(version.errors[:entities]).to eq([ "reference each other in a circle: Order → Customer → Order" ])
  end

  it "accepts entities nested in a chain" do
    expect(version_with("Address" => "{city:string}", "Customer" => "{address:Address}")).to be_valid
  end
end

describe Version, "#existing_endpoints_for_frontend" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }
  let!(:version) { FactoryBot.create(:version, project: project, name: "v1") }

  # Form.jsx rebuilds this exact string from live state to decide whether
  # anything changed. A new key, a reordered key or a stray space makes the two
  # strings never match, and submit stays enabled forever.
  it "serializes an endpoint the way Form.jsx rebuilds it" do
    endpoint = FactoryBot.create(:endpoint, version: version, path: "/tasks/:taskId",
                                            http_verb: "verb_get", note: "One task", input: "")
    FactoryBot.create(:endpoint_param, endpoint: endpoint, name: "taskId", kind: "number")
    FactoryBot.create(:response, endpoint: endpoint, code: "200", output: "string", note: "ok")

    expect(version.reload.existing_endpoints_for_frontend).to eq(
      '[{"http_verb":"verb_get","verb":"GET","path":"/tasks/:taskId","auth":"",' \
      '"params":[{"name":"taskId","kind":"number"}],"query_params":[],"note":"One task","input":"",' \
      '"schema_notes":[],' \
      '"responses":[{"code":"200","note":"ok","output":"string","schema_notes":[]}]}]'
    )
  end

  it "sends an empty param list for a path that takes none" do
    endpoint = FactoryBot.create(:endpoint, version: version, path: "/tasks",
                                            http_verb: "verb_get", note: "", input: "")
    FactoryBot.create(:response, endpoint: endpoint, code: "200", output: "string", note: "ok")

    expect(version.reload.existing_endpoints_for_frontend).to include('"params":[]')
  end

  it "sends the default kind for a path param with no stored row" do
    endpoint = FactoryBot.create(:endpoint, version: version, path: "/tasks/:taskId",
                                            http_verb: "verb_get", note: "", input: "")
    FactoryBot.create(:response, endpoint: endpoint, code: "200", output: "string", note: "ok")

    expect(version.reload.existing_endpoints_for_frontend).to include('"params":[{"name":"taskId","kind":"string"}]')
  end

  it "serializes an auth method the way Form.jsx rebuilds it" do
    FactoryBot.create(:auth_method, version: version, name: "UserToken", kind: "bearer",
                                    note: "Token from POST /sessions")

    expect(version.reload.existing_auth_methods_for_frontend).to eq(
      '[{"name":"UserToken","kind":"bearer","note":"Token from POST /sessions"}]'
    )
  end
end
