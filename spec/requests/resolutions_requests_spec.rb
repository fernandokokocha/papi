require "rails_helper"

describe "Resolutions requests", type: :request do
  let(:group) { FactoryBot.create :group, name: "Test group" }
  let(:author) { FactoryBot.create :user, email_address: "author@example.com", password: "password", group: group }
  let(:other) { FactoryBot.create :user, email_address: "other@example.com", password: "password", group: group }
  let(:project) { FactoryBot.create :project, name: "project", group: group }
  let(:candidate) { FactoryBot.create :candidate, project: project, name: "rc1", author: author }
  let(:thread) { FactoryBot.create :comment, candidate: candidate, author: author }

  describe "#create (resolve)" do
    it "marks the thread resolved and replaces it via turbo-stream" do
      sign_in(author)
      post project_candidate_comment_resolution_path(project.name, candidate.name, thread), as: :turbo_stream

      expect(thread.reload).to be_resolved
      expect(thread.resolved_by).to eq(author)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("action=\"replace\" target=\"#{ActionView::RecordIdentifier.dom_id(thread)}\"")
      expect(response.body).to include("Resolved by author@example.com")
      expect(response.body).to include("Reopen")
      expect(response.body).not_to include("Resolve thread")
    end

    it "echoes the line_badge into the re-render" do
      sign_in(author)
      post project_candidate_comment_resolution_path(project.name, candidate.name, thread),
           params: { line_badge: "collapsed" }, as: :turbo_stream
      expect(response.body).to include(">Collapsed<")
    end

    it "forbids a non-author" do
      sign_in(other)
      post project_candidate_comment_resolution_path(project.name, candidate.name, thread)
      expect(thread.reload).not_to be_resolved
    end
  end

  describe "#destroy (reopen)" do
    let(:thread) { FactoryBot.create :comment, :resolved, candidate: candidate, author: author }

    it "clears the resolution and re-renders the open thread" do
      sign_in(author)
      delete project_candidate_comment_resolution_path(project.name, candidate.name, thread), as: :turbo_stream

      expect(thread.reload).not_to be_resolved
      expect(response.body).to include("action=\"replace\" target=\"#{ActionView::RecordIdentifier.dom_id(thread)}\"")
      expect(response.body).not_to include("Resolved by")
      expect(response.body).to include("Resolve thread")
      expect(response.body).not_to include("Reopen")
    end
  end
end
