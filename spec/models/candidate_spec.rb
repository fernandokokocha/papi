require "rails_helper"

describe Candidate do
  describe "#comment_threads_by_anchor" do
    let(:candidate) { FactoryBot.create(:candidate) }

    it "groups root comments by anchor key and excludes replies" do
      root = FactoryBot.create(:comment, :endpoint_scope, candidate: candidate)
      reply = FactoryBot.create(:comment, candidate: candidate, parent: root, body: "A reply")
      candidate_level = FactoryBot.create(:comment, candidate: candidate)

      map = candidate.comment_threads_by_anchor

      expect(map[[ "endpoint", "/users", 0, nil, nil, "whole", nil ]]).to eq([ root ])
      expect(map[[ "candidate", nil, nil, nil, nil, "whole", nil ]]).to eq([ candidate_level ])
      expect(map.values.flatten).not_to include(reply)
    end

    it "sorts threads within an anchor by creation time" do
      newer = FactoryBot.create(:comment, candidate: candidate, created_at: 2.days.ago)
      older = FactoryBot.create(:comment, candidate: candidate, created_at: 5.days.ago)

      map = candidate.comment_threads_by_anchor

      expect(map[[ "candidate", nil, nil, nil, nil, "whole", nil ]]).to eq([ older, newer ])
    end
  end

  describe "#promoted_version" do
    it "returns the merged candidate's version" do
      candidate = FactoryBot.create(:candidate, aasm_state: "merged")
      version = FactoryBot.create(:version, candidate: candidate, name: "v1", order: 1)

      expect(candidate.promoted_version).to eq(version)
    end

    it "returns nil for an open candidate" do
      candidate = FactoryBot.create(:candidate, aasm_state: "open")
      FactoryBot.create(:version, candidate: candidate)

      expect(candidate.promoted_version).to be_nil
    end

    it "returns nil for a rejected candidate" do
      candidate = FactoryBot.create(:candidate, aasm_state: "rejected")
      FactoryBot.create(:version, candidate: candidate)

      expect(candidate.promoted_version).to be_nil
    end
  end
end
