require "rails_helper"

describe "History requests", type: :request do
  let!(:group) { Group.create!(name: "Test group") }
  let!(:user) { User.create!(email_address: "test@example.com", password: "password", group: group) }
  let!(:project) { Project.create!(name: "project", group: group) }

  let!(:another_group) { Group.create!(name: "Test group 2") }
  let!(:another_user) { User.create!(email_address: "test2@example.com", password: "password", group: another_group) }

  let!(:candidate1) { FactoryBot.create(:candidate, name: "rc1", project: project, order: 1) }
  let!(:v1) { FactoryBot.create(:version, project: project, candidate: candidate1, name: "v1", order: 1) }
  let!(:candidate2) { FactoryBot.create(:candidate, name: "rc2", project: project, order: 2, base_version: v1) }
  let!(:v2) { FactoryBot.create(:version, project: project, candidate: candidate2, name: "v2", order: 2) }

  describe "entity history" do
    it "shows a milestone for each version that touched the entity, and none for the others" do
      FactoryBot.create(:entity, version: v1, name: "User", root: "{id:number}")
      latest = FactoryBot.create(:entity, version: v2, name: "User", root: "{id:number,email:string}")

      sign_in(user)
      get project_entity_history_path(project_name: project.name, entity_id: latest.id)

      expect(response.status).to eq(200)
      expect(response.body).to include("Added")
      expect(response.body).to include("Changed")
      expect(response.body).to include("email")
    end

    it "explains itself when no published version carries the entity" do
      unpublished_candidate = FactoryBot.create(:candidate, name: "open", project: project, order: 3)
      unpublished = FactoryBot.create(:version, project: nil, candidate: unpublished_candidate, name: "rc-v1", order: 1)
      fresh = FactoryBot.create(:entity, version: unpublished, name: "Invoice", root: "{id:number}")

      sign_in(user)
      get project_entity_history_path(project_name: project.name, entity_id: fresh.id)

      expect(response.status).to eq(200)
      expect(response.body).to include("No published history yet")
    end

    it "refuses a member of another group" do
      entity = FactoryBot.create(:entity, version: v2, name: "User", root: "{id:number}")

      sign_in(another_user)
      get project_entity_history_path(project_name: project.name, entity_id: entity.id)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "endpoint history" do
    it "reaches history from a version in which the endpoint no longer exists" do
      removed = FactoryBot.create(:endpoint, version: v1, path: "/users/:id", http_verb: "verb_delete", input: "")

      sign_in(user)
      get project_endpoint_history_path(project_name: project.name, endpoint_id: removed.id)

      expect(response.status).to eq(200)
      expect(response.body).to include("Added")
      expect(response.body).to include("Removed")
    end

    it "resolves the endpoint whatever the param is named" do
      FactoryBot.create(:endpoint, version: v1, path: "/tasks/:taskId", http_verb: "verb_get", input: "")
      renamed = FactoryBot.create(:endpoint, version: v2, path: "/tasks/:id", http_verb: "verb_get", input: "")

      sign_in(user)
      get project_endpoint_history_path(project_name: project.name, endpoint_id: renamed.id)

      expect(response.status).to eq(200)
      expect(response.body).to include("Added")
      expect(response.body).to include("Changed")
    end
  end

  describe "entry points" do
    it "links to history from every card on a version page" do
      entity = FactoryBot.create(:entity, version: v2, name: "User", root: "{id:number}")
      endpoint = FactoryBot.create(:endpoint, version: v2, path: "/users", http_verb: "verb_get", input: "")

      sign_in(user)
      get project_version_path(project_name: project.name, name: v2.name)

      expect(response.body).to include(project_entity_history_path(project_name: project.name, entity_id: entity.id))
      expect(response.body).to include(project_endpoint_history_path(project_name: project.name, endpoint_id: endpoint.id))
    end
  end
end
