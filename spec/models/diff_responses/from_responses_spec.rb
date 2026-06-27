require "rails_helper"

describe DiffResponses::FromResponses, type: :model do
  let(:group) { FactoryBot.create(:group) }
  let(:project) { FactoryBot.create(:project, group: group) }
  let(:candidate) { FactoryBot.create(:candidate, project: project) }
  let(:version) { FactoryBot.create(:version, project: project, candidate: candidate) }
  let(:endpoint) { FactoryBot.create(:endpoint, version: version) }

  def response(code, note: "", output: "string")
    FactoryBot.build(:response, endpoint: endpoint, code: code, note: note, output: output)
  end

  it "sorts lines by code over the union of both sides" do
    diff = described_class.new([ response("200") ], [ response("404"), response("200") ])
    expect(diff.lines.map(&:code)).to eq(%w[200 404])
  end

  it "marks a response present only on the right as added" do
    diff = described_class.new([], [ response("201") ])
    line = diff.lines.first
    expect(line.state).to eq(:added)
    expect(line.before_present?).to be(false)
    expect(line.after_present?).to be(true)
  end

  it "marks a response present only on the left as removed" do
    diff = described_class.new([ response("500") ], [])
    expect(diff.lines.first.state).to eq(:removed)
  end

  it "marks a response with a changed schema as changed" do
    diff = described_class.new([ response("200", output: "string") ],
                              [ response("200", output: "number") ])
    expect(diff.lines.first.state).to eq(:changed)
  end

  it "marks a response with a changed note as changed" do
    diff = described_class.new([ response("200", note: "old") ],
                              [ response("200", note: "new") ])
    expect(diff.lines.first.state).to eq(:changed)
  end

  it "marks an identical response as no_change" do
    diff = described_class.new([ response("200", note: "n", output: "string") ],
                              [ response("200", note: "n", output: "string") ])
    expect(diff.lines.first.state).to eq(:no_change)
  end

  it "any_changes? is true when any line changed" do
    expect(described_class.new([], [ response("200") ]).any_changes?).to be(true)
    expect(described_class.new([ response("200") ], [ response("200") ]).any_changes?).to be(false)
  end
end
