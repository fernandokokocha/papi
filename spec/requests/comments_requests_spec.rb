require "rails_helper"

describe "Comments requests", type: :request do
  let(:group) { FactoryBot.create :group, name: "Test group" }
  let(:user) { FactoryBot.create :user, email_address: "test@example.com", password: "password", group: group }
  let(:project) { FactoryBot.create :project, name: "project", group: group }
  let(:candidate) { FactoryBot.create :candidate, project: project, name: "rc1" }

  let(:another_group) { FactoryBot.create :group, name: "Test group 2" }
  let(:another_user) { FactoryBot.create :user, email_address: "test2@example.com", password: "password", group: another_group }

  describe "#create" do
    it "creates a candidate-level root comment authored by the signed-in user" do
      sign_in(user)
      post project_candidate_comments_path(project.name, candidate.name),
           params: { comment: { body: "First!" } }

      comment = Comment.last
      expect(comment.body).to eq("First!")
      expect(comment.author).to eq(user)
      expect(comment.candidate).to eq(candidate)
      expect(comment.scope).to eq("candidate")
      expect(comment.part).to eq("whole")
      expect(comment.root?).to be true
      expect(response).to redirect_to(project_candidate_path(project.name, candidate.name))
    end

    it "creates a reply that inherits the root's anchor" do
      root = FactoryBot.create :comment, candidate: candidate
      sign_in(user)
      post project_candidate_comments_path(project.name, candidate.name),
           params: { comment: { body: "Agreed.", parent_id: root.id } }

      reply = Comment.last
      expect(reply.parent).to eq(root)
      expect(reply.anchor_key).to eq(root.anchor_key)
    end

    it "does not create a comment for a user outside the group" do
      sign_in(another_user)
      expect {
        post project_candidate_comments_path(project.name, candidate.name),
             params: { comment: { body: "Sneaky" } }
      }.not_to change(Comment, :count)
      expect(response).to redirect_to("/")
      expect(flash[:alert]).to eq("You are not authorized to perform this action.")
    end

    it "rejects a reply to a reply" do
      root = FactoryBot.create :comment, candidate: candidate
      reply = FactoryBot.create :comment, candidate: candidate, parent: root
      sign_in(user)
      expect {
        post project_candidate_comments_path(project.name, candidate.name),
             params: { comment: { body: "Too deep", parent_id: reply.id } }
      }.not_to change(Comment, :count)
      expect(flash[:alert]).to eq("Comment could not be posted.")
    end

    it "rejects a blank body" do
      sign_in(user)
      expect {
        post project_candidate_comments_path(project.name, candidate.name),
             params: { comment: { body: "" } }
      }.not_to change(Comment, :count)
      expect(flash[:alert]).to eq("Comment could not be posted.")
    end

    it "rejects a parent from another candidate" do
      other_candidate = FactoryBot.create :candidate, project: project, name: "rc2"
      foreign_root = FactoryBot.create :comment, candidate: other_candidate
      sign_in(user)
      expect {
        post project_candidate_comments_path(project.name, candidate.name),
             params: { comment: { body: "Crossed wires", parent_id: foreign_root.id } }
      }.not_to change(Comment, :count)
      expect(flash[:alert]).to eq("Comment could not be posted.")
    end

    it "ignores a client-supplied author_id" do
      forged = FactoryBot.create :user, email_address: "forged@example.com", group: group
      sign_in(user)
      post project_candidate_comments_path(project.name, candidate.name),
           params: { comment: { body: "Hi", author_id: forged.id } }
      expect(Comment.last.author).to eq(user)
    end

    it "answers a turbo stream that appends the new thread and resets the form" do
      sign_in(user)
      post project_candidate_comments_path(project.name, candidate.name),
           params: { comment: { body: "First!" } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('action="append" target="candidate_comment_threads"')
      expect(response.body).to include('action="remove" target="no_comments_message"')
      expect(response.body).to include('action="update" target="new_comment_form"')
      expect(response.body).to include("First!")

      textarea_contents = response.body.scan(%r{<textarea[^>]*>([\s\S]*?)</textarea>}).flatten
      expect(textarea_contents).not_to be_empty
      expect(textarea_contents).to all(be_blank)
    end

    it "answers a turbo stream that appends a reply into its thread" do
      root = FactoryBot.create :comment, candidate: candidate
      sign_in(user)
      post project_candidate_comments_path(project.name, candidate.name),
           params: { comment: { body: "Agreed.", parent_id: root.id } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(action="append" target="replies_comment_#{root.id}"))
      expect(response.body).to include(%(action="update" target="reply_form_comment_#{root.id}"))
      expect(response.body).to include("Agreed.")
    end
  end
end
