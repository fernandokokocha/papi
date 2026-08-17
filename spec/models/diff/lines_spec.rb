require "rails_helper"

describe Diff::Lines do
  def parse(schema)
    JSONSchemaParser.new([]).parse_whole_value(schema)
  end

  describe "#nothing?" do
    it "is true for a side padded out to face a schema the other side gained" do
      diff = Diff::FromValues.new(parse(""), parse("{ids:[number]}"))

      expect(diff.before.nothing?).to be(true)
      expect(diff.after.nothing?).to be(false)
    end

    it "is false when the side carries lines of its own, changed or not" do
      diff = Diff::FromValues.new(parse("{id:number}"), parse("{id:string}"))

      expect(diff.before.nothing?).to be(false)
      expect(diff.after.nothing?).to be(false)
    end

    it "is true when neither side declares anything" do
      diff = Diff::FromValues.new(parse(""), parse(""))

      expect(diff.before.nothing?).to be(true)
    end
  end
end
