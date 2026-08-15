require "rails_helper"

describe "Approvals requests", type: :request do
  let(:group) { FactoryBot.create :group, name: "Test group" }
  let(:author) { FactoryBot.create :user, email_address: "author@example.com", password: "password", group: group }
  let(:reviewer) { FactoryBot.create :user, email_address: "reviewer@example.com", password: "password", group: group }
  let(:outsider) { FactoryBot.create :user, email_address: "outsider@example.com", password: "password" }
  let(:project) { FactoryBot.create :project, name: "proj", group: group }
  let(:candidate) { FactoryBot.create :candidate, project: project, name: "rc1", author: author }

  describe "#create" do
    it "records an approval for a group member" do
      sign_in(reviewer)

      post project_candidate_approval_path(project.name, candidate.name)

      expect(candidate.approvers).to eq([ reviewer ])
      expect(response).to redirect_to(project_candidate_path(project.name, candidate.name))
    end

    it "approves only once per user" do
      sign_in(reviewer)
      post project_candidate_approval_path(project.name, candidate.name)

      post project_candidate_approval_path(project.name, candidate.name)

      expect(candidate.approvals.count).to eq(1)
    end

    it "refuses the author" do
      sign_in(author)

      post project_candidate_approval_path(project.name, candidate.name)

      expect(candidate.approvals.count).to eq(0)
      expect(flash[:alert]).to eq("You are not authorized to perform this action.")
    end

    it "refuses someone outside the group" do
      sign_in(outsider)

      post project_candidate_approval_path(project.name, candidate.name)

      expect(candidate.approvals.count).to eq(0)
      expect(flash[:alert]).to eq("You are not authorized to perform this action.")
    end

    it "refuses a candidate that is no longer open" do
      candidate.merge!
      sign_in(reviewer)

      post project_candidate_approval_path(project.name, candidate.name)

      expect(candidate.approvals.count).to eq(0)
      expect(flash[:alert]).to eq("You are not authorized to perform this action.")
    end
  end

  describe "#destroy" do
    it "withdraws the approval of the signed in user" do
      other_reviewer = FactoryBot.create :user, group: group
      FactoryBot.create :approval, candidate: candidate, user: other_reviewer
      FactoryBot.create :approval, candidate: candidate, user: reviewer
      sign_in(reviewer)

      delete project_candidate_approval_path(project.name, candidate.name)

      expect(candidate.approvers).to eq([ other_reviewer ])
      expect(response).to redirect_to(project_candidate_path(project.name, candidate.name))
    end
  end

  describe "rendering" do
    it "names the approvers on the candidate page" do
      FactoryBot.create :approval, candidate: candidate, user: reviewer
      sign_in(author)

      get project_candidate_path(project.name, candidate.name)

      expect(response.body).to include("Approved by reviewer@example.com")
    end

    it "offers the button to a reviewer and withdraws it from the author" do
      sign_in(reviewer)
      get project_candidate_path(project.name, candidate.name)
      expect(response.body).to include("👍 Approve")

      sign_in(author)
      get project_candidate_path(project.name, candidate.name)
      expect(response.body).not_to include("👍 Approve")
    end

    it "offers a reviewer who already approved the way back" do
      FactoryBot.create :approval, candidate: candidate, user: reviewer
      sign_in(reviewer)

      get project_candidate_path(project.name, candidate.name)

      expect(response.body).to include("Approved ✓")
    end

    it "counts the approvals in the candidate history" do
      candidate.merge!
      FactoryBot.create :approval, candidate: candidate, user: reviewer
      sign_in(reviewer)

      get projects_path

      row = Nokogiri::HTML5(response.body).css("table tbody tr").first
      expect(row.css("td")[6].text.strip).to eq("1")
    end
  end
end
