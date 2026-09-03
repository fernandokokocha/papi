require "rails_helper"

describe Schema::Node::Object, type: :model do
  def object(attributes)
    Schema::Node::Object.new(
      object_attributes: attributes.map { |name, value| Schema::Node::ObjectAttribute.new(name: name, value: value) }
    )
  end

  let(:string) { Schema::Node::Primitive.new(kind: "string") }
  let(:number) { Schema::Node::Primitive.new(kind: "number") }

  describe "#==" do
    it "is true for the same attributes" do
      expect(object("a" => string)).to eq(object("a" => string))
    end

    it "is false when an attribute value differs" do
      expect(object("a" => string)).not_to eq(object("a" => number))
    end

    it "is false when the other has an extra attribute" do
      expect(object("a" => string)).not_to eq(object("a" => string, "b" => number))
    end

    it "is false when the other is missing an attribute" do
      expect(object("a" => string, "b" => number)).not_to eq(object("a" => string))
    end

    it "is false when the other has no attributes at all" do
      expect(object({})).not_to eq(object("a" => string))
    end

    it "is false for a node of another kind" do
      expect(object("a" => string)).not_to eq(string)
    end

    it "is false when one attribute is optional and the other is not" do
      required = Schema::Node::Object.new(object_attributes: [ Schema::Node::ObjectAttribute.new(name: "a", value: string) ])
      optional = Schema::Node::Object.new(object_attributes: [ Schema::Node::ObjectAttribute.new(name: "a", value: string, optional: true) ])

      expect(required).not_to eq(optional)
    end
  end

  describe "#expand" do
    it "keeps the optional flag" do
      attribute = Schema::Node::ObjectAttribute.new(name: "nickname", value: string, optional: true)
      expanded = Schema::Node::Object.new(object_attributes: [ attribute ]).expand

      expect(expanded.object_attributes.first.optional).to eq(true)
    end
  end
end
