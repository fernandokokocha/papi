require "rails_helper"

describe Node::OneOf, type: :model do
  def attachment = Entity.new(name: "Attachment", root: "{id:number,url:string}")

  def parse(source) = JSONSchemaParser.new([ attachment ]).parse_value(source)

  describe "#serialize" do
    it "round-trips a union" do
      expect(parse("(string|number)").serialize).to eq("(string|number)")
    end

    it "round-trips a union nested in an object" do
      expect(parse("{a:(string|[number]),b:string}").serialize).to eq("{a:(string|[number]),b:string}")
    end
  end

  describe "#to_example_json" do
    it "takes the first branch" do
      expect(parse("(number|string)").to_example_json).to eq("0")
    end
  end

  describe "#expandable?" do
    it "is true when a branch is an entity" do
      expect(parse("(boolean|Attachment)")).to be_expandable
    end

    it "is false when no branch is an entity" do
      expect(parse("(string|number)")).not_to be_expandable
    end
  end

  describe "#expand" do
    it "inlines the root of an entity branch" do
      expect(parse("(boolean|Attachment)").expand.serialize).to eq("(boolean|{id:number,url:string})")
    end
  end

  describe "#==" do
    it "is true for the same branches in the same order" do
      expect(parse("(string|number)")).to eq(parse("(string|number)"))
    end

    it "is false when the branches are reordered" do
      expect(parse("(string|number)")).not_to eq(parse("(number|string)"))
    end

    it "is false for a node of another kind" do
      expect(parse("(string|number)")).not_to eq(parse("string"))
    end
  end
end
