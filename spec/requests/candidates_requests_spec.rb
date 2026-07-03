require "rails_helper"

describe "Candidates requests", type: :request do
  let(:group) { FactoryBot.create :group, name: "Test group" }
  let(:user) { FactoryBot.create :user, email_address: "test@example.com", password: "password", group: group, role: 0 }
  let(:project) { FactoryBot.create :project, name: "project", group: group }
  let(:author) { FactoryBot.create :user, email_address: "author@example.com", group: group }

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
          { path: "/",
            http_verb: "verb_get",
            responses: { "200" => { note: "ok", output: "User" } }
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

  describe "#create" do
    it "creates a candidate with valid params" do
      sign_in(user)

      expect(Version.count).to eq(0)
      post project_candidates_path(project.name), params: valid_params
      expect(Version.count).to eq(1)
      expect(response.status).to eq(302)
      expect(response).to redirect_to(project_candidate_path(project.name, "rc1"))
    end

    it "persists response note and output through real controller params" do
      sign_in(user)
      post project_candidates_path(project.name), params: valid_params

      endpoint = Endpoint.last
      response_record = endpoint.responses.find_by(code: "200")
      expect(response_record.note).to eq("ok")
      expect(response_record.output).to eq("User")
    end

    it "does not create a version if user outside group" do
      sign_in(another_user)
      post project_candidates_path(project.name), params: valid_params
      expect(Version.count).to eq(0)
      expect(response.status).to eq(302)
      expect(response).to redirect_to('/')
      expect(flash[:alert]).to eq('You are not authorized to perform this action.')
    end

    it "records the signed-in user as the author" do
      sign_in(user)
      post project_candidates_path(project.name), params: valid_params
      expect(Candidate.last.author).to eq(user)
    end

    it "ignores a client-supplied decided_by_id on create" do
      sign_in(user)
      forged = FactoryBot.create(:user, email_address: "forged@example.com", group: group)
      post project_candidates_path(project.name),
           params: valid_params.deep_merge(candidate: { decided_by_id: forged.id, decided_at: Time.current })
      expect(Candidate.last.decided_by).to be_nil
      expect(Candidate.last.decided_at).to be_nil
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

    it "shows who proposed the candidate" do
      authored = FactoryBot.create(:candidate, project: project, author: author)
      sign_in(user)
      get project_candidate_path(project.name, authored.name)
      expect(response.body).to include("Proposed by")
      expect(response.body).to include("author@example.com")
    end

    it "shows who rejected the candidate" do
      rejected = FactoryBot.create(:candidate, project: project, author: author, decided_by: author, aasm_state: "rejected")
      sign_in(user)
      get project_candidate_path(project.name, rejected.name)
      expect(response.body).to include("Rejected by")
      expect(response.body).to include("author@example.com")
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

      patch project_candidate_path(project_name: project.name, name: candidate_name), params: valid_params
      expect(response.status).to eq(302)
      expect(flash[:alert]).to be_nil
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
    it "renders candidate-level comments with an Author badge for the candidate author" do
      candidate = FactoryBot.create :candidate, project: project, name: "rc9", author: author
      FactoryBot.create :comment, candidate: candidate, author: author, body: "Comment by the candidate author"
      FactoryBot.create :comment, candidate: candidate, author: user, body: "Comment by a reviewer"

      sign_in(user)
      get project_candidate_path(project.name, candidate.name)

      expect(response.status).to eq(200)
      expect(response.body).to include("Conversation")
      expect(response.body).to include("Comment by the candidate author")
      expect(response.body).to include("Comment by a reviewer")
      expect(response.body).to include("Author")
    end
  end
end
