require "rails_helper"

describe CandidateComments do
  let(:candidate) { FactoryBot.create(:candidate) }
  let(:endpoint) { FactoryBot.create(:endpoint, path: "/users", http_verb: "verb_get") }
  let(:other_endpoint) { FactoryBot.create(:endpoint, path: "/tasks", http_verb: "verb_get") }
  let(:entity) { FactoryBot.create(:entity, name: "User") }

  def comments = described_class.for(candidate)

  describe "without a candidate" do
    it "answers empty to every reader" do
      FactoryBot.create(:comment, :endpoint_scope, candidate: candidate)
      none = described_class.for(nil)

      expect(none.threads_for("endpoint", endpoint: endpoint)).to eq([])
      expect(none.sidebar_count(CommentAnchor.for_endpoint(endpoint))).to eq(0)
      expect(none.card_for_endpoint(endpoint)).to eq(whole: [], lines: [])
      expect(none.card_for_entity(entity)).to eq(whole: [], lines: [])
      expect(none.response_output_lines(endpoint, "200")).to eq(described_class::LineComments.new(fresh: [], outdated: []))
      expect(none.entity_root_lines(entity)).to eq(described_class::LineComments.new(fresh: [], outdated: []))
    end
  end

  describe "#threads_for" do
    it "finds threads by scope and identity, sorted by creation time" do
      note = FactoryBot.create(:comment, :endpoint_scope, candidate: candidate, part: "note", created_at: 2.days.ago)
      whole = FactoryBot.create(:comment, :endpoint_scope, candidate: candidate, created_at: 1.day.ago)
      entity_thread = FactoryBot.create(:comment, :entity_scope, candidate: candidate)
      response_thread = FactoryBot.create(:comment, :response_scope, candidate: candidate)

      # every part of the scope when none is named
      expect(comments.threads_for("endpoint", endpoint: endpoint)).to eq([ note, whole ])

      # narrowed to one part
      expect(comments.threads_for("endpoint", endpoint: endpoint, part: "whole")).to eq([ whole ])
      expect(comments.threads_for("endpoint", endpoint: endpoint, part: "note")).to eq([ note ])

      # other scopes
      expect(comments.threads_for("entity", entity: entity)).to eq([ entity_thread ])
      expect(comments.threads_for("response", endpoint: endpoint, response_code: "200")).to eq([ response_thread ])

      # identity has to match
      expect(comments.threads_for("endpoint", endpoint: other_endpoint)).to eq([])
      expect(comments.threads_for("response", endpoint: endpoint, response_code: "404")).to eq([])
    end

    it "excludes line-anchored threads" do
      FactoryBot.create(:comment, :response_scope, candidate: candidate, part: "output", line: 2, anchor_snapshot: "x")

      expect(comments.threads_for("response", endpoint: endpoint, response_code: "200")).to eq([])
    end
  end

  describe "#sidebar_count" do
    it "counts every thread under the target, not replies" do
      root = FactoryBot.create(:comment, :endpoint_scope, candidate: candidate)
      FactoryBot.create(:comment, candidate: candidate, parent: root, body: "A reply")
      FactoryBot.create(:comment, :endpoint_scope, candidate: candidate, part: "note")
      FactoryBot.create(:comment, :response_scope, candidate: candidate)
      FactoryBot.create(:comment, :entity_scope, candidate: candidate)

      expect(comments.sidebar_count(CommentAnchor.for_endpoint(endpoint))).to eq(3)
      expect(comments.sidebar_count(CommentAnchor.for_endpoint(other_endpoint))).to eq(0)
      expect(comments.sidebar_count(CommentAnchor.for_entity(entity))).to eq(1)
      expect(comments.sidebar_count(CommentAnchor.for_entity(FactoryBot.create(:entity, name: "Task")))).to eq(0)
    end
  end

  describe "#card_for_endpoint / #card_for_entity" do
    it "splits a card's threads into whole-scope and line-anchored" do
      whole = FactoryBot.create(:comment, :endpoint_scope, candidate: candidate)
      response_whole = FactoryBot.create(:comment, :response_scope, candidate: candidate)
      line = FactoryBot.create(:comment, :response_scope, candidate: candidate, part: "output", line: 2, anchor_snapshot: "x")
      entity_whole = FactoryBot.create(:comment, :entity_scope, candidate: candidate)
      entity_line = FactoryBot.create(:comment, :entity_scope, candidate: candidate, part: "root", line: 0, anchor_snapshot: "x")

      endpoint_card = comments.card_for_endpoint(endpoint)
      expect(endpoint_card[:whole]).to contain_exactly(whole, response_whole)
      expect(endpoint_card[:lines]).to eq([ line ])

      entity_card = comments.card_for_entity(entity)
      expect(entity_card[:whole]).to eq([ entity_whole ])
      expect(entity_card[:lines]).to eq([ entity_line ])

      expect(comments.card_for_endpoint(other_endpoint)).to eq(whole: [], lines: [])
    end
  end

  describe "line readers" do
    it "splits line-anchored threads into fresh and outdated, ordered by line" do
      FactoryBot.create(:response, endpoint: endpoint, code: "200", output: "{id:number}")
      entity.update!(root: "{name:string}")

      second = FactoryBot.create(:comment, :response_scope, candidate: candidate, part: "output", line: 5, anchor_snapshot: "{id:number}")
      first = FactoryBot.create(:comment, :response_scope, candidate: candidate, part: "output", line: 2, anchor_snapshot: "{id:number}")
      stale = FactoryBot.create(:comment, :response_scope, candidate: candidate, part: "output", line: 3, anchor_snapshot: "{id:number,legacy:string}")
      entity_line = FactoryBot.create(:comment, :entity_scope, candidate: candidate, part: "root", line: 0, anchor_snapshot: "{name:string}")
      entity_stale = FactoryBot.create(:comment, :entity_scope, candidate: candidate, part: "root", line: 1, anchor_snapshot: "{name:string,legacy:string}")

      response_lines = comments.response_output_lines(endpoint, "200")
      entity_lines = comments.entity_root_lines(entity)

      # a snapshot matching the current text is fresh, ordered by line
      expect(response_lines.fresh).to eq([ first, second ])
      expect(entity_lines.fresh).to eq([ entity_line ])

      # anything else outdated, whatever the text changed to
      expect(response_lines.outdated).to eq([ stale ])
      expect(entity_lines.outdated).to eq([ entity_stale ])

      # fresh threads indexed by line for inline rendering
      expect(response_lines.by_line).to eq(2 => [ first ], 5 => [ second ])

      # identity has to match
      expect(comments.response_output_lines(endpoint, "404").fresh).to eq([])
    end

    it "treats every thread as outdated when the anchored text is gone" do
      orphan = FactoryBot.create(:comment, :response_scope, candidate: candidate, part: "output", line: 2, anchor_snapshot: "{id:number}")

      expect(comments.response_output_lines(endpoint, "200").outdated).to eq([ orphan ])
    end
  end
end
