require "rails_helper"

describe "Rejections requests", type: :request do
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
              { path: "/",
                http_verb: "verb_get",
                output: "",
                output_error: "",
                auth: "bearer"
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

      before do
        sign_in(admin)
        post project_candidates_path(project.name), params: valid_params
        @candidate = Candidate.last
        @candidate_version = @candidate.latest_version
      end

      it "merges a candidate if admin from the group" do
        sign_in(admin)

        expect(project.versions.count).to eq(0)
        post project_candidate_rejection_path(project.name, @candidate.name)
        expect(project.versions.count).to eq(0)
        expect(@candidate.reload).to be_rejected
        expect(response.status).to eq(302)
        expect(response).to redirect_to(root_path)
      end

      it "does not accept if regular user from the group" do
        sign_in(user)

        expect(project.versions.count).to eq(0)
        post project_candidate_rejection_path(project.name, @candidate.name)
        expect(project.versions.count).to eq(0)
        expect(@candidate.reload).to be_open
        expect(flash[:alert]).to eq('You are not authorized to perform this action.')
      end

      it "does not accept if admin from outside the group" do
        sign_in(another_user)

        expect(project.versions.count).to eq(0)
        post project_candidate_rejection_path(project.name, @candidate.name)
        expect(project.versions.count).to eq(0)
        expect(@candidate.reload).to be_open
        expect(flash[:alert]).to eq('You are not authorized to perform this action.')
      end
    end
  end
end
