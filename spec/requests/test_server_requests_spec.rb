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

  describe "auth" do
    let!(:guarded) do
      FactoryBot.create(:auth_method, version: version, name: "UserToken", kind: "bearer")
      FactoryBot.create(:endpoint, version: version, http_verb: "verb_get", path: "/me", auth: "UserToken").tap do |e|
        FactoryBot.create(:response, endpoint: e, code: "200", output: "{ id: number }")
      end
    end

    it "serves an endpoint whose declared scheme is present" do
      get "/projects/proj/versions/v1/me", headers: { "Authorization" => "Bearer anything-at-all" }

      expect(response.status).to eq(200)
      expect(response.body).to include("id")
    end

    it "refuses a request that sends no Authorization header" do
      get "/projects/proj/versions/v1/me"

      expect(response.status).to eq(401)
      expect(response.parsed_body["error"]).to eq("UserToken required")
      expect(response.headers["WWW-Authenticate"]).to eq("Bearer")
    end

    it "refuses the wrong scheme" do
      get "/projects/proj/versions/v1/me", headers: { "Authorization" => "Basic anything-at-all" }

      expect(response.status).to eq(401)
    end

    it "refuses a scheme with nothing after it" do
      get "/projects/proj/versions/v1/me", headers: { "Authorization" => "Bearer " }

      expect(response.status).to eq(401)
    end

    it "leaves an endpoint that declares no auth open" do
      get "/projects/proj/versions/v1/users"

      expect(response.status).to eq(200)
    end

    it "guards a candidate's mock the same way" do
      candidate = FactoryBot.create(:candidate, project: project, name: "rc1")
      draft = FactoryBot.create(:version, project: nil, candidate: candidate, name: "rc1-v1")
      FactoryBot.create(:auth_method, version: draft, name: "UserToken", kind: "bearer")
      drafted = FactoryBot.create(:endpoint, version: draft, http_verb: "verb_get", path: "/me", auth: "UserToken")
      FactoryBot.create(:response, endpoint: drafted, code: "200", output: "{ id: number }")

      get "/projects/proj/candidates/rc1/me"
      expect(response.status).to eq(401)

      get "/projects/proj/candidates/rc1/me", headers: { "Authorization" => "Bearer t" }
      expect(response.status).to eq(200)
    end

    it "checks basic against its own scheme" do
      FactoryBot.create(:auth_method, version: version, name: "AdminBasic", kind: "basic")
      admin = FactoryBot.create(:endpoint, version: version, http_verb: "verb_get", path: "/admin", auth: "AdminBasic")
      FactoryBot.create(:response, endpoint: admin, code: "200", output: "{ ok: boolean }")

      get "/projects/proj/versions/v1/admin", headers: { "Authorization" => "Basic dXNlcjpwYXNz" }

      expect(response.status).to eq(200)
    end
  end

  describe "query params" do
    let!(:search) do
      FactoryBot.create(:endpoint, version: version, http_verb: "verb_get", path: "/search").tap do |e|
        FactoryBot.create(:response, endpoint: e, code: "200", output: "{ hits: number }")
        FactoryBot.create(:endpoint_param, :query, endpoint: e, name: "q", kind: "string", required: true)
        FactoryBot.create(:endpoint_param, :query, endpoint: e, name: "page", kind: "number", required: false)
      end
    end

    it "serves the endpoint when every required param is present" do
      get "/projects/proj/versions/v1/search", params: { q: "hello" }

      expect(response.status).to eq(200)
      expect(response.body).to include("hits")
    end

    it "raises when a required param is missing" do
      expect {
        get "/projects/proj/versions/v1/search"
      }.to raise_error(TestServerController::MissingRequiredParam, /q/)
    end

    it "accepts any value, since kinds are not checked" do
      get "/projects/proj/versions/v1/search", params: { q: "" }
      expect(response.status).to eq(200)
    end

    it "does not count a route segment as a query param" do
      FactoryBot.create(:endpoint_param, :query, endpoint: search, name: "version_name", kind: "string", required: true)

      expect {
        get "/projects/proj/versions/v1/search", params: { q: "hello" }
      }.to raise_error(TestServerController::MissingRequiredParam, /version_name/)
    end
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
