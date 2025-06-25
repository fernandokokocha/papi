require "rails_helper"

describe VersionsController, type: :request do
  let!(:group) { Group.create!(name: "Test group") }
  let!(:user) { User.create!(email_address: "test@example.com", password: "password", group: group) }
  let!(:project) { Project.create!(name: "project", group: group) }

  let!(:another_group) { Group.create!(name: "Test group 2") }
  let!(:another_user) { User.create!(email_address: "test2@example.com", password: "password", group: another_group) }
  let!(:another_project) { Project.create!(name: "project", group: another_group) }

  describe "#create" do
    it "creates a version with valid params" do
      sign_in(user)

      expect(Version.count).to eq(0)
      post project_versions_path(project.name), params: {
        version: {
          project_id: project.id,
          name: "v1",
          order: 1,
          endpoints_attributes: [
            { url: "/",
              http_verb: "verb_get",
              original_output_string: "",
              original_input_string: ""
            }
          ],
          entities_attributes: [
            { name: "User",
              original_root: "{ name: string }"
            }
          ]
        }
      }
      expect(Version.count).to eq(1)
      expect(response.status).to eq(302)
      expect(response).to redirect_to(project_version_path(project.name, "v1"))
    end

    it "does not create a version with taken name within a project" do
      sign_in(user)
      post project_versions_path(project.name), params: {
        version: {
          project_id: project.id,
          name: "v1",
          order: 1,
          endpoints_attributes: [
            { url: "/",
              http_verb: "verb_get",
              original_output_string: "",
              original_input_string: ""
            }
          ],
          entities_attributes: [
            { name: "User",
              original_root: "{ name: string }"
            }
          ]
        }
      }
      expect(Version.count).to eq(1)

      post project_versions_path(project.name), params: {
        version: {
          project_id: project.id,
          name: "v1",
          order: 1,
          endpoints_attributes: [
            { url: "/",
              http_verb: "verb_get",
              original_output_string: "",
              original_input_string: ""
            }
          ],
          entities_attributes: [
            { name: "User",
              original_root: "{ name: string }"
            }
          ]
        }
      }
      expect(Version.count).to eq(1)

      expect(response.status).to eq(302)
      expect(response).to redirect_to(new_project_version_path(project.name))
    end

    it "does not create a version if user outside group" do
      sign_in(user)
      post project_versions_path(project.name), params: {
        version: {
          project_id: another_project.id,
          name: "v1",
          order: 1,
          endpoints_attributes: [
            { url: "/",
              http_verb: "verb_get",
              original_output_string: "",
              original_input_string: ""
            }
          ],
          entities_attributes: [
            { name: "User",
              original_root: "{ name: string }"
            }
          ]
        }
      }
      expect(Version.count).to eq(0)
      expect(response.status).to eq(302)
      expect(response).to redirect_to('/')
      expect(flash[:alert]).to eq('You are not authorized to perform this action.')
    end
  end

  describe "#show" do
    let(:version) { FactoryBot.create(:version, project: project) }

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

  describe "#new" do
    it "accepts users from the project group" do
      sign_in(user)
      get new_project_version_path(project.name)
      expect(response.status).to eq(200)
    end

    it "does not accept users from the project group" do
      sign_in(another_user)
      get new_project_version_path(project.name)
      expect(response.status).to eq(302)
      expect(response).to redirect_to('/')
      expect(flash[:alert]).to eq('You are not authorized to perform this action.')
    end
  end
end
