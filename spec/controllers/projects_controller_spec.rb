require "rails_helper"

describe ProjectsController, type: :request do
  let!(:group) { Group.create!(name: "Test group") }
  let!(:user) { User.create!(email_address: "test@example.com", password: "password", group: group) }

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
  end
end
