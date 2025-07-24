require "rails_helper"

describe "Endpoints requests", type: :request do
  let!(:group) { Group.create!(name: "Test group") }
  let!(:user) { User.create!(email_address: "test@example.com", password: "password", group: group) }
  let!(:project) { Project.create!(name: "project", group: group) }

  let!(:another_group) { Group.create!(name: "Test group 2") }
  let!(:another_user) { User.create!(email_address: "test2@example.com", password: "password", group: another_group) }
  let!(:another_project) { Project.create!(name: "project", group: another_group) }

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

  describe "#show" do
    let(:candidate) { FactoryBot.create(:candidate, project: project) }

    it "accepts users from the project group" do
      sign_in(user)
      post project_candidates_path(project.name), params: valid_params
      endpoint = Endpoint.last
      get project_endpoint_path(project.name, endpoint.id)
      expect(response.status).to eq(200)
    end

    # it "does not accept users from the project group" do
    #   sign_in(another_user)
    #   get project_candidate_path(project.name, candidate.name)
    #   expect(response.status).to eq(302)
    #   expect(response).to redirect_to('/')
    #   expect(flash[:alert]).to eq('You are not authorized to perform this action.')
    # end
  end
end
