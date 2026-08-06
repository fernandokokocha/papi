require "rails_helper"

describe Diff::Line, type: :model do
  it "tokenizes null as its own type rather than as an entity" do
    line = Diff::Line.new("null", :no_change, 0)

    expect(line.type).to eq("null")
    expect(line.class_name).to eq("null")
  end

  it "keeps null tokenized once it carries an attribute name" do
    line = Diff::Line.new("null", :no_change, 0)
    line.add_parent("a")

    expect(line.class_name).to eq("null")
    expect(line.pre_type).to eq("a: ")
  end
end
