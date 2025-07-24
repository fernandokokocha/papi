require "rails_helper"

describe "Version requests", type: :request do
  let!(:group) { Group.create!(name: "Test group") }
  let!(:user) { User.create!(email_address: "test@example.com", password: "password", group: group) }
  let!(:project) { Project.create!(name: "project", group: group) }

  let!(:another_group) { Group.create!(name: "Test group 2") }
  let!(:another_user) { User.create!(email_address: "test2@example.com", password: "password", group: another_group) }
  let!(:another_project) { Project.create!(name: "project", group: another_group) }

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
  end
end
