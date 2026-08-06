require "rails_helper"

describe Node::Primitive, type: :model do
  def parse(source) = JSONSchemaParser.new.parse_value(source)

  describe "#serialize" do
    it "round-trips null" do
      expect(parse("null").serialize).to eq("null")
    end

    it "round-trips a nullable attribute" do
      expect(parse("{a:(string|null)}").serialize).to eq("{a:(string|null)}")
    end
  end

  describe "#to_example_json" do
    it "renders null as the JSON literal" do
      expect(parse("null").to_example_json).to eq("null")
    end

    it "renders a nullable attribute from its first branch" do
      expect(parse("{a:(null|string)}").to_example_json).to eq('{ "a": null }')
    end
  end
end
