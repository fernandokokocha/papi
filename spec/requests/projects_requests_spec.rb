require "rails_helper"

describe "Projects requests", type: :request do
  let(:group) { FactoryBot.create :group, name: "Test group" }
  let(:user) { FactoryBot.create :user, email_address: "test@example.com", password: "password", group: group, role: 0 }

  let(:another_group) { FactoryBot.create :group, name: "Test group 2" }
  let(:another_user) { FactoryBot.create :user, email_address: "test3@example.com", password: "password", group: another_group }

  describe "#index" do
    it "lists each project against its current version and its open candidate" do
      project = FactoryBot.create(:project, name: "proj", group: group)
      merged = FactoryBot.create(:candidate, project: project, name: "rc1", aasm_state: "merged")
      FactoryBot.create(:version, project: project, candidate: merged, name: "v1", order: 1,
                                  release_notes: "The first cut")
      teammate = FactoryBot.create(:user, email_address: "test2@example.com", group: group)
      open_candidate = FactoryBot.create(:candidate, project: project, name: "rc2", author: user)
      FactoryBot.create(:comment, candidate: open_candidate, author: user)
      FactoryBot.create(:approval, candidate: open_candidate, user: teammate)
      sign_in(user)

      get projects_path

      expect(response.body).to include("proj")
      expect(response.body).to include(project_version_path(project.name, "v1"))
      expect(response.body).to include(project_candidate_path(project.name, "rc2"))
      expect(response.body).to include("The first cut")
      expect(response.body).to include(user.email_address)
    end

    it "dashes the candidate columns of a project with nothing open" do
      FactoryBot.create(:project, name: "quiet", group: group)
      sign_in(user)

      get projects_path

      expect(response.body).to include("quiet")
      expect(response.body).to include("—")
    end
  end

  describe "#show rail and panel" do
    let(:project) { FactoryBot.create(:project, name: "proj", group: group) }

    def release(name, version_name, order)
      candidate = FactoryBot.create(:candidate, project: project, name: name, order: order,
                                    aasm_state: "merged", author: user, decided_by: user)
      FactoryBot.create(:version, project: project, candidate: candidate, name: version_name, order: order,
                                  release_notes: "Notes for #{version_name}")
      candidate
    end

    it "opens on the current release and links through to its diff" do
      release("rc1", "v1", 1)
      release("rc2", "v2", 2)
      sign_in(user)

      get project_path(project.name)

      expect(response.body).to include("Notes for v2")
      expect(response.body).to include("See what changed since")
      expect(response.body).to include(project_version_path(project.name, "v2"))
    end

    it "selects an earlier release from the rail" do
      release("rc1", "v1", 1)
      release("rc2", "v2", 2)
      sign_in(user)

      get project_path(project.name, version: "v1")

      expect(response.body).to include("Notes for v1")
      expect(response.body).not_to include("Notes for v2")
    end

    it "shows a candidate rather than a release under the candidates tab" do
      release("rc1", "v1", 1)
      FactoryBot.create(:candidate, project: project, name: "rc2", order: 2, author: user)
      sign_in(user)

      get project_path(project.name, tab: "candidates", candidate: "rc2")

      expect(response.body).to include("Review")
      expect(response.body).to include(project_candidate_path(project.name, "rc2"))
      expect(response.body).to include("Open for")
    end

    it "renders both rail tabs whichever one is showing" do
      release("rc1", "v1", 1)
      sign_in(user)

      get project_path(project.name)

      expect(response.body).to include("Releases")
      expect(response.body).to include("Candidates")
      expect(response.body).to include(project_path(project.name, tab: "candidates"))
    end
  end

  describe "#show history" do
    let(:project) { FactoryBot.create(:project, name: "proj", group: group) }

    it "renders the candidate history with version mapping" do
      candidate = FactoryBot.create(:candidate, project: project, name: "rc1", aasm_state: "merged")
      FactoryBot.create(:version, project: project, candidate: candidate, name: "v1", order: 1)
      sign_in(user)

      get project_path(project.name)

      expect(response.body).to include("rc1")
      expect(response.body).to include(project_version_path(project.name, "v1"))
      expect(response.body).to include(project_candidate_path(project.name, "rc1"))
    end

    it "offers both ways into a new candidate" do
      sign_in(user)

      get project_path(project.name)

      expect(response.body).to include(new_project_openapi_import_path(project_name: project.name))
      expect(response.body).to include(new_project_candidate_path(project_name: project.name))
    end

    it "grays both of them out while a candidate is open" do
      FactoryBot.create(:candidate, project: project, name: "rc1")
      sign_in(user)

      get project_path(project.name)

      expect(response.body).to include("Import OpenAPI")
      expect(response.body).to include("New candidate")
      expect(response.body).not_to include(new_project_openapi_import_path(project_name: project.name))
      expect(response.body).not_to include(new_project_candidate_path(project_name: project.name))
    end
  end

  describe "#create" do
    it "creates a project with valid params" do
      sign_in(user)

      expect(Project.count).to eq(0)
      post projects_path, params: { project: { name: "Test Project", group_id: group.id } }
      expect(Project.count).to eq(1)
      expect(response.status).to eq(302)
    end

    it "does not create a project with taken name within a group" do
      sign_in(user)
      post projects_path, params: { project: { name: "Test Project", group_id: group.id } }
      expect(Project.count).to eq(1)

      post projects_path, params: { project: { name: "Test Project", group_id: group.id } }
      expect(response.status).to eq(422)
      expect(Project.count).to eq(1)
    end

    it "does not create a project with a different group" do
      sign_in(user)
      post projects_path, params: { project: { name: "Test Project", group_id: another_group.id } }
      expect(Project.count).to eq(0)
      expect(response.status).to eq(302)
      expect(response).to redirect_to('/projects')
      expect(flash[:alert]).to eq('You are not authorized to perform this action.')
    end
  end
end
