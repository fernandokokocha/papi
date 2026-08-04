require "rails_helper"

describe Comment::Create do
  let(:group) { FactoryBot.create :group }
  let(:project) { FactoryBot.create :project, group: group }
  let(:candidate) { FactoryBot.create :candidate, project: project }
  let(:user) { FactoryBot.create :user, group: group }

  it "builds a candidate-scope root authored by the given user" do
    service = described_class.new(candidate, { body: "First!" }, {}, author: user)

    expect(service.call).to be true
    expect(service.comment.author).to eq(user)
    expect(service.comment.candidate).to eq(candidate)
    expect(service.comment.scope).to eq("candidate")
    expect(service.comment.part).to eq("whole")
    expect(service.comment.root?).to be true
  end

  it "derives the anchor columns from the anchor params" do
    anchor = { scope: "endpoint", part: "whole", endpoint_path: "/users", endpoint_http_verb: "0" }
    service = described_class.new(candidate, { body: "Pin me" }, anchor, author: user)

    expect(service.call).to be true
    expect(service.comment.scope).to eq("endpoint")
    expect(service.comment.endpoint_path).to eq("/users")
    expect(service.comment.endpoint_http_verb).to eq(0)
    expect(service.comment.line).to be_nil
  end

  it "reports failure and leaves an invalid comment unsaved" do
    service = described_class.new(candidate, { body: "" }, {}, author: user)

    expect(service.call).to be false
    expect(service.comment).not_to be_persisted
  end

  it "reopens a resolved parent when the comment is a reply" do
    parent = FactoryBot.create :comment, :resolved, candidate: candidate
    service = described_class.new(candidate, { body: "One more thing", parent_id: parent.id }, {}, author: user)

    expect(service.call).to be true
    expect(service.reopened_parent).to be true
    expect(parent.reload).not_to be_resolved
  end

  it "leaves an open parent alone when the comment is a reply" do
    parent = FactoryBot.create :comment, candidate: candidate
    service = described_class.new(candidate, { body: "Agreed", parent_id: parent.id }, {}, author: user)

    expect(service.call).to be true
    expect(service.reopened_parent).to be false
  end

  describe "line anchors" do
    let!(:version) { FactoryBot.create :version, candidate: candidate, project: project, order: 1 }
    let!(:endpoint) { FactoryBot.create :endpoint, version: version, path: "/users", http_verb: "verb_get" }
    let!(:response) { FactoryBot.create :response, endpoint: endpoint, code: "200", output: "{total:number,items:[User]}" }
    let!(:entity) { FactoryBot.create :entity, version: version, name: "User", root: "{id:number,email:string}" }

    it "resolves the snapshot against the candidate's latest version" do
      output = described_class.new(candidate, { body: "Pinned to the User row" },
        { scope: "response", part: "output", endpoint_path: "/users", endpoint_http_verb: "0",
          response_code: "200", line: "4" }, author: user)
      root = described_class.new(candidate, { body: "Pinned to email" },
        { scope: "entity", part: "root", entity_name: "User", line: "2" }, author: user)

      expect(output.call).to be true
      expect(output.comment.line).to eq(4)
      expect(output.comment.anchor_snapshot).to eq("{total:number,items:[User]}")

      expect(root.call).to be true
      expect(root.comment.line).to eq(2)
      expect(root.comment.anchor_snapshot).to eq("{id:number,email:string}")
    end
  end
end
