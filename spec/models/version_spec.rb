require "rails_helper"

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

    expect(version.existing_endpoints_for_frontend).to eq(
      '[{"http_verb":"verb_get","verb":"GET","path":"/tasks/:taskId",' \
      '"params":[{"name":"taskId","kind":"number"}],"note":"One task","input":"",' \
      '"responses":[{"code":"200","note":"ok","output":"string"}]}]'
    )
  end

  it "sends an empty param list for a path that takes none" do
    endpoint = FactoryBot.create(:endpoint, version: version, path: "/tasks",
                                            http_verb: "verb_get", note: "", input: "")
    FactoryBot.create(:response, endpoint: endpoint, code: "200", output: "string", note: "ok")

    expect(version.existing_endpoints_for_frontend).to include('"params":[]')
  end

  it "sends the default kind for a path param with no stored row" do
    endpoint = FactoryBot.create(:endpoint, version: version, path: "/tasks/:taskId",
                                            http_verb: "verb_get", note: "", input: "")
    FactoryBot.create(:response, endpoint: endpoint, code: "200", output: "string", note: "ok")

    expect(version.existing_endpoints_for_frontend).to include('"params":[{"name":"taskId","kind":"string"}]')
  end
end
