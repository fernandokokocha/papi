require "rails_helper"

describe "Merges requests", type: :request do
  let(:group) { FactoryBot.create :group, name: "Test group" }
  let(:user) { FactoryBot.create :user, email_address: "test@example.com", password: "password", group: group, role: 0 }
  let(:project) { FactoryBot.create :project, name: "project", group: group }

  let(:another_group) { FactoryBot.create :group, name: "Test group 2" }
  let(:another_user) { FactoryBot.create :user, email_address: "test2@example.com", password: "password", group: another_group }
  let(:another_project) { FactoryBot.create :project, name: "project 2", group: another_group }

  let(:admin) { FactoryBot.create :user, email_address: "test3@example.com", password: "password", group: group, role: 1 }

  describe "#create" do
    context "given candidate is created" do
      let(:valid_params) {
        {
          candidate: {
            project_id: project.id,
            name: 'rc1'
          },
          version: {
            name: "rc1",
            order: 1,
            endpoints_attributes: [
              { url: "/",
                http_verb: "verb_get",
                original_output_string: "",
                original_input_string: "",
                auth: "bearer"
              }
            ],
            entities_attributes: [
              { name: "User",
                original_root: "{ name: string }"
              }
            ]
          }
        }
      }

      before do
        sign_in(admin)
        post project_candidates_path(project.name), params: valid_params
        @candidate = Candidate.last
        @candidate_version = @candidate.latest_version

        expect(@candidate_version.name).to eq("rc1")
      end

      it "merges a candidate if admin from the group" do
        sign_in(admin)

        expect(project.versions.count).to eq(0)
        post project_candidate_merge_path(project.name, @candidate.name)
        expect(project.versions.count).to eq(1)
        expect(project.latest_version).to eq(@candidate_version)
        expect(project.latest_version.name).to eq("v1")
        expect(response.status).to eq(302)
        expect(response).to redirect_to(project_version_path(project.name, "v1"))
      end

      it "does not accept if regular user from the group" do
        sign_in(user)

        expect(project.versions.count).to eq(0)
        post project_candidate_merge_path(project.name, @candidate.name)
        expect(project.versions.count).to eq(0)
        expect(flash[:alert]).to eq('You are not authorized to perform this action.')
      end

      it "does not accept if admin from outside the group" do
        sign_in(another_user)

        expect(project.versions.count).to eq(0)
        post project_candidate_merge_path(project.name, @candidate.name)
        expect(project.versions.count).to eq(0)
        expect(flash[:alert]).to eq('You are not authorized to perform this action.')
      end
    end
  end
end
