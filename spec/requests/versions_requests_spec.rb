require "rails_helper"

describe "Version requests", type: :request do
  let(:group) { FactoryBot.create :group, name: "Test group" }
  let(:user) { FactoryBot.create :user, email_address: "test@example.com", password: "password", group: group, role: 0 }
  let(:project) { FactoryBot.create :project, name: "project", group: group }

  let(:another_group) { FactoryBot.create :group, name: "Test group 2" }
  let(:another_user) { FactoryBot.create :user, email_address: "test3@example.com", password: "password", group: another_group }
  let(:another_project) { FactoryBot.create :project, name: "project 2", group: another_group }

  let(:author) { FactoryBot.create :user, email_address: "author@example.com", group: group }
  let(:decider) { FactoryBot.create :user, email_address: "decider@example.com", group: group }

  describe "#show" do
    let(:candidate) { FactoryBot.create(:candidate, project: project) }
    let(:version) { FactoryBot.create(:version, candidate: candidate, project: project) }

    it "accepts users from the project group" do
      sign_in(user)
      get project_version_path(project.name, version.name)
      expect(response.status).to eq(200)
    end

    it "does not accept users from the project group" do
      sign_in(another_user)
      get project_version_path(project.name, version.name)
      expect(response.status).to eq(302)
      expect(response).to redirect_to('/')
      expect(flash[:alert]).to eq('You are not authorized to perform this action.')
    end

    it "shows who proposed and merged the version" do
      attributed_candidate = FactoryBot.create(:candidate, project: project, author: author, decided_by: decider, aasm_state: "merged")
      attributed_version = FactoryBot.create(:version, project: project, candidate: attributed_candidate, name: "v1", order: 1)
      sign_in(user)
      get project_version_path(project.name, attributed_version.name)
      expect(response.status).to eq(200)
      expect(response.body).to include("Proposed by")
      expect(response.body).to include("author@example.com")
      expect(response.body).to include("Merged by")
      expect(response.body).to include("decider@example.com")
    end

    it "does not render candidate comment threads on the version page" do
      merged_candidate = FactoryBot.create(:candidate, project: project, aasm_state: "merged")
      merged_version = FactoryBot.create(:version, candidate: merged_candidate, project: project)
      merged_endpoint = FactoryBot.create(:endpoint, version: merged_version, path: "/users", http_verb: "verb_get")
      FactoryBot.create(:response, endpoint: merged_endpoint, code: "200", output: "{total:number,items:[string]}")
      merged_candidate.comments.create!(author: user, body: "Endpoint thread body", scope: "endpoint", part: "whole", endpoint_path: "/users", endpoint_http_verb: 0)
      merged_candidate.comments.create!(author: user, body: "Line thread body", scope: "response", part: "output",
                                         endpoint_path: "/users", endpoint_http_verb: 0, response_code: "200",
                                         line: 0, anchor_snapshot: "[string]")

      sign_in(user)
      get project_version_path(project.name, merged_version.name)

      expect(response.status).to eq(200)
      expect(response.body).not_to include("Endpoint thread body")
      expect(response.body).not_to include("💬")
      expect(response.body).not_to include("data-comment-region")
      expect(response.body).not_to include("Outdated")
      expect(response.body).not_to include("· line 0")
    end
  end
end
