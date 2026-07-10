require "rails_helper"

describe Comment do
  let(:author) { FactoryBot.create :user }
  let(:candidate) { FactoryBot.create :candidate, author: author }

  it "builds a valid candidate-scope root from the factory" do
    expect(FactoryBot.build(:comment)).to be_valid
  end

  it "requires a body" do
    expect(FactoryBot.build(:comment, body: "")).not_to be_valid
  end

  it "surfaces CommentAnchor errors on the record" do
    comment = FactoryBot.build(:comment, scope: "candidate", part: "whole", entity_name: "User")
    expect(comment).not_to be_valid
    expect(comment.errors[:entity_name]).to be_present
  end

  it "requires a snapshot on a line comment" do
    comment = FactoryBot.build :comment, :response_scope, part: "output", line: 4
    expect(comment).not_to be_valid
    expect(comment.errors[:anchor_snapshot]).to be_present
    comment.anchor_snapshot = "{total:number}"
    expect(comment).to be_valid
  end

  describe "one-level threading" do
    it "allows a reply to a root" do
      root = FactoryBot.create :comment, candidate: candidate
      expect(FactoryBot.build(:comment, candidate: candidate, parent: root)).to be_valid
    end

    it "rejects a reply to a reply" do
      root = FactoryBot.create :comment, candidate: candidate
      reply = FactoryBot.create :comment, candidate: candidate, parent: root
      expect(FactoryBot.build(:comment, candidate: candidate, parent: reply)).not_to be_valid
    end

    it "rejects a reply whose candidate differs from its parent's" do
      root = FactoryBot.create :comment, candidate: candidate
      other_candidate = FactoryBot.create :candidate, project: candidate.project
      expect(FactoryBot.build(:comment, candidate: other_candidate, parent: root)).not_to be_valid
    end
  end

  describe "#root? / #reply?" do
    it "is a root when parent is nil" do
      comment = FactoryBot.build :comment
      expect(comment.root?).to be true
      expect(comment.reply?).to be false
    end

    it "is a reply when parent is set" do
      root = FactoryBot.create :comment, candidate: candidate
      reply = FactoryBot.build :comment, candidate: candidate, parent: root
      expect(reply.reply?).to be true
    end
  end

  describe "#by_candidate_author?" do
    it "is true when the comment author is the candidate author" do
      expect(FactoryBot.build(:comment, candidate: candidate, author: author).by_candidate_author?).to be true
    end

    it "is false for anyone else" do
      other = FactoryBot.create :user
      expect(FactoryBot.build(:comment, candidate: candidate, author: other).by_candidate_author?).to be false
    end
  end

  describe "#anchor_key" do
    it "delegates to the anchor's key" do
      comment = FactoryBot.build :comment, :response_scope, part: "output", line: 7
      expect(comment.anchor_key).to eq([ "response", "/users", 0, nil, "200", "output", 7 ])
    end
  end

  describe "anchor inheritance" do
    it "copies the parent's anchor onto a reply" do
      root = FactoryBot.create :comment, :endpoint_scope, candidate: candidate
      reply = FactoryBot.create :comment, candidate: candidate, parent: root
      expect(reply.scope).to eq("endpoint")
      expect(reply.endpoint_path).to eq("/users")
      expect(reply.endpoint_http_verb).to eq(0)
      expect(reply.anchor_key).to eq(root.anchor_key)
    end

    it "overrides anchor attributes supplied on the reply itself" do
      root = FactoryBot.create :comment, candidate: candidate
      reply = FactoryBot.create :comment, :entity_scope, candidate: candidate, parent: root
      expect(reply.scope).to eq("candidate")
      expect(reply.entity_name).to be_nil
    end
  end

  describe "resolution" do
    it "#resolved? reflects resolved_at" do
      expect(FactoryBot.build(:comment)).not_to be_resolved
      expect(FactoryBot.build(:comment, :resolved)).to be_resolved
    end

    it "rejects a reply that carries a resolution" do
      root = FactoryBot.create :comment
      reply = FactoryBot.build :comment, candidate: root.candidate, parent: root, resolved_at: Time.current
      expect(reply).not_to be_valid
      expect(reply.errors[:resolved_at]).to be_present
    end

    it "auto-reopens a resolved parent when a reply is created" do
      root = FactoryBot.create :comment, :resolved
      expect(root).to be_resolved

      reply = FactoryBot.create :comment, candidate: root.candidate, parent: root
      expect(reply.reopened_parent?).to be true
      expect(root.reload).not_to be_resolved
      expect(root.resolved_by_id).to be_nil
    end

    it "does not flag reopened_parent when the parent was already open" do
      root = FactoryBot.create :comment
      reply = FactoryBot.create :comment, candidate: root.candidate, parent: root
      expect(reply.reopened_parent?).to be false
    end
  end
end
