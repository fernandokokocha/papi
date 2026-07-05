require "rails_helper"

describe CommentsHelper, type: :helper do
  let(:candidate) { FactoryBot.create(:candidate) }
  let(:endpoint) { FactoryBot.create(:endpoint, path: "/users", http_verb: "verb_get") }
  let(:entity) { FactoryBot.create(:entity, name: "User") }

  def assign_map
    assign(:comment_threads_by_anchor, candidate.comment_threads_by_anchor)
  end

  it "returns [] when no anchor map is assigned" do
    FactoryBot.create(:comment, :endpoint_scope, candidate: candidate)

    expect(helper.comment_threads_for("endpoint", endpoint: endpoint)).to eq([])
  end

  it "finds endpoint threads across parts, sorted by creation time" do
    note_thread = FactoryBot.create(:comment, :endpoint_scope, candidate: candidate, part: "note", created_at: 2.days.ago)
    whole_thread = FactoryBot.create(:comment, :endpoint_scope, candidate: candidate, created_at: 1.day.ago)
    assign_map

    expect(helper.comment_threads_for("endpoint", endpoint: endpoint)).to eq([ note_thread, whole_thread ])
  end

  it "does not match a different endpoint" do
    FactoryBot.create(:comment, :endpoint_scope, candidate: candidate)
    other = FactoryBot.create(:endpoint, path: "/tasks", http_verb: "verb_get")
    assign_map

    expect(helper.comment_threads_for("endpoint", endpoint: other)).to eq([])
  end

  it "finds entity threads by name" do
    thread = FactoryBot.create(:comment, :entity_scope, candidate: candidate)
    assign_map

    expect(helper.comment_threads_for("entity", entity: entity)).to eq([ thread ])
  end

  it "finds response threads by endpoint identity and code" do
    thread = FactoryBot.create(:comment, :response_scope, candidate: candidate)
    assign_map

    expect(helper.comment_threads_for("response", endpoint: endpoint, response_code: "200")).to eq([ thread ])
    expect(helper.comment_threads_for("response", endpoint: endpoint, response_code: "404")).to eq([])
  end

  it "filters to a single part when given" do
    note_thread = FactoryBot.create(:comment, :endpoint_scope, candidate: candidate, part: "note")
    whole_thread = FactoryBot.create(:comment, :endpoint_scope, candidate: candidate)
    assign_map

    expect(helper.comment_threads_for("endpoint", endpoint: endpoint, part: "whole")).to eq([ whole_thread ])
    expect(helper.comment_threads_for("endpoint", endpoint: endpoint, part: "note")).to eq([ note_thread ])
  end

  it "counts endpoint threads across parts and response codes, not replies" do
    root = FactoryBot.create(:comment, :endpoint_scope, candidate: candidate)
    FactoryBot.create(:comment, candidate: candidate, parent: root, body: "A reply")
    FactoryBot.create(:comment, :endpoint_scope, candidate: candidate, part: "note")
    FactoryBot.create(:comment, :response_scope, candidate: candidate)
    assign_map

    expect(helper.endpoint_comment_thread_count(endpoint)).to eq(3)
    other = FactoryBot.create(:endpoint, path: "/tasks", http_verb: "verb_get")
    expect(helper.endpoint_comment_thread_count(other)).to eq(0)
  end

  it "counts entity threads by name" do
    FactoryBot.create(:comment, :entity_scope, candidate: candidate)
    assign_map

    expect(helper.entity_comment_thread_count(entity)).to eq(1)
    expect(helper.entity_comment_thread_count(FactoryBot.create(:entity, name: "Task"))).to eq(0)
  end

  it "returns 0 counts when no anchor map is assigned" do
    FactoryBot.create(:comment, :endpoint_scope, candidate: candidate)

    expect(helper.endpoint_comment_thread_count(endpoint)).to eq(0)
  end
end
