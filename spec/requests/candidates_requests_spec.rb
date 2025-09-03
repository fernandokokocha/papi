require "rails_helper"

describe "Candidates requests", type: :request do
  let(:group) { FactoryBot.create :group, name: "Test group" }
  let(:user) { FactoryBot.create :user, email_address: "test@example.com", password: "password", group: group, role: 0 }
  let(:project) { FactoryBot.create :project, name: "project", group: group }

  let(:another_group) { FactoryBot.create :group, name: "Test group 2" }
  let(:another_user) { FactoryBot.create :user, email_address: "test2@example.com", password: "password", group: another_group }
  let(:another_project) { FactoryBot.create :project, name: "project 2", group: another_group }

  let(:admin) { FactoryBot.create :user, email_address: "test3@example.com", password: "password", group: group, role: 1 }

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

  describe "#create" do
    it "creates a candidate with valid params" do
      sign_in(user)

      expect(Version.count).to eq(0)
      post project_candidates_path(project.name), params: valid_params
      expect(Version.count).to eq(1)
      expect(response.status).to eq(302)
      expect(response).to redirect_to(project_candidate_path(project.name, "rc1"))
    end

    it "does not create a version if user outside group" do
      sign_in(another_user)
      post project_candidates_path(project.name), params: valid_params
      expect(Version.count).to eq(0)
      expect(response.status).to eq(302)
      expect(response).to redirect_to('/')
      expect(flash[:alert]).to eq('You are not authorized to perform this action.')
    end
  end

  describe "#show" do
    let(:candidate) { FactoryBot.create(:candidate, project: project) }

    it "accepts users from the project group" do
      sign_in(user)
      get project_candidate_path(project.name, candidate.name)
      expect(response.status).to eq(200)
    end

    it "does not accept users from the project group" do
      sign_in(another_user)
      get project_candidate_path(project.name, candidate.name)
      expect(response.status).to eq(302)
      expect(response).to redirect_to('/')
      expect(flash[:alert]).to eq('You are not authorized to perform this action.')
    end
  end

  describe "#new" do
    it "accepts users from the project group" do
      sign_in(user)
      get new_project_candidate_path(project.name)
      expect(response.status).to eq(200)
    end

    it "does not accept users from the project group" do
      sign_in(another_user)
      get new_project_candidate_path(project.name)
      expect(response.status).to eq(302)
      expect(response).to redirect_to('/')
      expect(flash[:alert]).to eq('You are not authorized to perform this action.')
    end
  end

  describe "#update" do
    it "updates a candidate with valid params" do
      sign_in(admin)
      post project_candidates_path(project.name), params: valid_params
      candidate_name = Candidate.last.name

      patch project_candidate_path(project_name: project.name, name: candidate_name), params: {}
      expect(response.status).to eq(302)
      expect(flash[:alert]).to be_nil
      expect(response).to redirect_to(project_candidate_path(project.name, "rc1"))
    end

    # it "does not create a version if user outside group" do
    #   sign_in(another_user)
    #   post project_candidates_path(project.name), params: valid_params
    #   expect(Version.count).to eq(0)
    #   expect(response.status).to eq(302)
    #   expect(response).to redirect_to('/')
    #   expect(flash[:alert]).to eq('You are not authorized to perform this action.')
    # end
  end
end
