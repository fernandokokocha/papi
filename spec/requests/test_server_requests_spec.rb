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
