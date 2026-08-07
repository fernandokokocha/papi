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

  describe "path params" do
    let!(:show) do
      FactoryBot.create(:endpoint, version: version, http_verb: "verb_get", path: "/users/:userId").tap do |e|
        FactoryBot.create(:response, endpoint: e, code: "200", output: "{ id: number }")
      end
    end

    it "serves a real value in place of the param" do
      get "/projects/proj/versions/v1/users/42"

      expect(response.status).to eq(200)
      expect(response.body).to include("id")
    end

    it "serves any value, not just the ones matching the param kind" do
      get "/projects/proj/versions/v1/users/anything"
      expect(response.status).to eq(200)
    end

    it "prefers a literal path over a param that would also match it" do
      literal = FactoryBot.create(:endpoint, version: version, http_verb: "verb_get", path: "/users/me")
      FactoryBot.create(:response, endpoint: literal, code: "200", output: "{ me: boolean }")

      get "/projects/proj/versions/v1/users/me"

      expect(response.body).to include("me")
      expect(response.body).not_to include("id")
    end

    it "does not match across a slash" do
      get "/projects/proj/versions/v1/users/42/comments"
      expect(response.status).to eq(404)
    end

    it "matches several params in one path" do
      nested = FactoryBot.create(:endpoint, version: version, http_verb: "verb_get", path: "/users/:userId/posts/:postId")
      FactoryBot.create(:response, endpoint: nested, code: "200", output: "{ title: string }")

      get "/projects/proj/versions/v1/users/42/posts/7"

      expect(response.body).to include("title")
    end
  end
end
