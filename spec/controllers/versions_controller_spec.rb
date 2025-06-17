require "rails_helper"

describe VersionsController, type: :request do
  let!(:group) { Group.create!(name: "Test group") }
  let!(:user) { User.create!(email_address: "test@example.com", password: "password", group: group) }
  let!(:project) { Project.create!(name: "project", group: group) }

  describe "#create" do
    it "creates a version with valid params" do
      sign_in(user)

      expect(Version.count).to eq(0)
      post project_versions_path(project.name), params: { version: { project_id: project.id, name: "v1", order: 1, endpoints_attributes: [ { url: "/", http_verb: "verb_get", original_output_string: "", original_input_string: "" } ] } }
      expect(Version.count).to eq(1)
      expect(response.status).to eq(302)
    end

    it "does not create a version with taken name within a project" do
      sign_in(user)
      post project_versions_path(project.name), params: { version: { project_id: project.id, name: "v1", order: 1, endpoints_attributes: [ { url: "/", http_verb: "verb_get", original_output_string: "", original_input_string: "" } ] } }
      expect(Version.count).to eq(1)

      post project_versions_path(project.name), params: { version: { project_id: project.id, name: "v1", order: 1, endpoints_attributes: [ { url: "/", http_verb: "verb_get", original_output_string: "", original_input_string: "" } ] } }
      expect(Version.count).to eq(1)
    end

    # it "does not create a version if user outside group"
  end
end
