require "rails_helper"

describe "Endpoints requests", type: :request do
  let!(:group) { Group.create!(name: "Test group") }
  let!(:user) { User.create!(email_address: "test@example.com", password: "password", group: group) }
  let!(:project) { Project.create!(name: "project", group: group) }

  let!(:another_group) { Group.create!(name: "Test group 2") }
  let!(:another_user) { User.create!(email_address: "test2@example.com", password: "password", group: another_group) }
  let!(:another_project) { Project.create!(name: "project2", group: another_group) }

  let(:valid_params) {
    {
      candidate: {
        project_id: project.id,
        name: 'rc1'
      },
      version: {
        name: "v1",
        order: 1,
        endpoints_attributes: [
          { path: "/",
            http_verb: "verb_get",
            auth: "bearer",
            responses: { "200" => { note: "ok", output: "User" } }
          }
        ],
        entities_attributes: [
          { name: "User",
            root: "{ name: string }"
          }
        ]
      }
    }
  }

  describe "#show" do
    let(:candidate) { FactoryBot.create(:candidate, project: project) }

    it "accepts users from the project group" do
      sign_in(user)
      post project_candidates_path(project.name), params: valid_params
      endpoint = Endpoint.last
      get project_endpoint_path(project.name, endpoint.id)
      expect(response.status).to eq(200)
    end

    it "does not accept users from outside the project group" do
      sign_in(another_user)
      get project_candidate_path(project.name, candidate.name)
      expect(response.status).to eq(302)
      expect(response).to redirect_to('/')
      expect(flash[:alert]).to eq('You are not authorized to perform this action.')
    end

    it "renders note- and response-anchored threads only when re-rendering for a candidate page" do
      sign_in(user)
      post project_candidates_path(project.name), params: valid_params
      candidate = Candidate.find_by!(name: "rc1")
      endpoint = Endpoint.last
      candidate.comments.create!(author: user, body: "Note thread body", scope: "endpoint", part: "note", endpoint_path: "/", endpoint_http_verb: 0)
      candidate.comments.create!(author: user, body: "Response thread body", scope: "response", part: "output", endpoint_path: "/", endpoint_http_verb: 0, response_code: "200")

      get project_endpoint_path(project.name, endpoint.id, candidate: candidate.name)
      expect(response.body).to include("Note thread body")
      expect(response.body).to include("Response thread body")

      get project_endpoint_path(project.name, endpoint.id)
      expect(response.body).not_to include("Note thread body")
      expect(response.body).not_to include("Response thread body")

      get project_endpoint_path(project.name, endpoint.id, candidate: candidate.name)
      expect(response.body).to include("data-comment-region")

      get project_endpoint_path(project.name, endpoint.id)
      expect(response.body).not_to include("data-comment-region")
    end

    it "does not leak threads from a candidate the endpoint does not belong to" do
      sign_in(user)
      post project_candidates_path(project.name), params: valid_params
      endpoint = Endpoint.last
      foreign_candidate = FactoryBot.create(:candidate, name: "rc-foreign", project: another_project)
      foreign_candidate.comments.create!(author: another_user, body: "Foreign thread body", scope: "endpoint", part: "note", endpoint_path: "/", endpoint_http_verb: 0)

      get project_endpoint_path(project.name, endpoint.id, candidate: foreign_candidate.name)
      expect(response.body).not_to include("Foreign thread body")

      get project_endpoint_path(another_project.name, endpoint.id, candidate: foreign_candidate.name)
      expect(response.body).not_to include("Foreign thread body")
    end

    it "keeps removed-endpoint threads on candidate-page re-renders" do
      base_candidate = FactoryBot.create(:candidate, name: "rc8", project: project)
      base_version = FactoryBot.create(:version, project: project, candidate: base_candidate, name: "v1", order: 1)
      removed_endpoint = FactoryBot.create(:endpoint, version: base_version, path: "/gone", http_verb: "verb_get")
      candidate = FactoryBot.create(:candidate, name: "rc9", project: project, base_version: base_version)
      candidate.comments.create!(author: user, body: "Removed thread body", scope: "endpoint", part: "note", endpoint_path: "/gone", endpoint_http_verb: 0)

      sign_in(user)
      get project_endpoint_path(project.name, removed_endpoint.id, kind: "removed", candidate: "rc9")
      expect(response.body).to include("Removed thread body")
    end
  end
end
