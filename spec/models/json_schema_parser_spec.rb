require "rails_helper"
require "ostruct"

describe JSONSchemaParser, type: :model do
  subject(:parser) { JSONSchemaParser.new }

  describe "#parse_value" do
    it "parse empty string" do
      actual = parser.parse_value("")
      expected = Node::Nothing.new
      expect(actual).to eq(expected)
    end

    it "parse {}" do
      actual = parser.parse_value("{}")
      expected = Node::Object.new
      expect(actual).to eq(expected)
    end

    it "parse { a: string }" do
      actual = parser.parse_value("{ a: string }")
      expected = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "a", value: Node::Primitive.new(kind: "string"))
      ])

      expect(actual).to eq(expected)
    end

    it "parse { a: number }" do
      actual = parser.parse_value("{ a: number }")
      expected = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "a", value: Node::Primitive.new(kind: "number"))
      ])

      expect(actual).to eq(expected)
    end

    it "parse { a: string, b: number }" do
      actual = parser.parse_value("{ a: string, b: number }")
      expected = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "a", value: Node::Primitive.new(kind: "string")),
        Node::ObjectAttribute.new(name: "b", value: Node::Primitive.new(kind: "number"))
      ])

      expect(actual).to eq(expected)
    end

    it "parse { a: { b: string } }" do
      actual = parser.parse_value("{ a: { b: string } }")
      expected = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "a", value: Node::Object.new(object_attributes: [
          Node::ObjectAttribute.new(name: "b", value: Node::Primitive.new(kind: "string"))
        ]))
      ])

      expect(actual).to eq(expected)
    end

    it "parse { a: { b: string, c: number } }" do
      actual = parser.parse_value("{ a: { b: string, c: number } }")
      expected = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "a", value: Node::Object.new(object_attributes: [
          Node::ObjectAttribute.new(name: "b", value: Node::Primitive.new(kind: "string")),
          Node::ObjectAttribute.new(name: "c", value: Node::Primitive.new(kind: "number"))
        ]))
      ])

      expect(actual).to eq(expected)
    end

    it "parse real life problem" do
      actual = parser.parse_value("{name:string,child:{first_name:string,last_name:string,third_name:number},elo:string}")
      expected = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "name", value: Node::Primitive.new(kind: "string")),
        Node::ObjectAttribute.new(name: "child", value: Node::Object.new(object_attributes: [
          Node::ObjectAttribute.new(name: "first_name", value: Node::Primitive.new(kind: "string")),
          Node::ObjectAttribute.new(name: "last_name", value: Node::Primitive.new(kind: "string")),
          Node::ObjectAttribute.new(name: "third_name", value: Node::Primitive.new(kind: "number"))
        ])),
        Node::ObjectAttribute.new(name: "elo", value: Node::Primitive.new(kind: "string"))
      ])

      expect(actual).to eq(expected)
    end

    it "parse three levels of nesting" do
      actual = parser.parse_value("{name:string,child:{first_name:string,last_name:string,obj:{new:string}}}")
      expected = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "name", value: Node::Primitive.new(kind: "string")),
        Node::ObjectAttribute.new(name: "child", value: Node::Object.new(object_attributes: [
          Node::ObjectAttribute.new(name: "first_name", value: Node::Primitive.new(kind: "string")),
          Node::ObjectAttribute.new(name: "last_name", value: Node::Primitive.new(kind: "string")),
          Node::ObjectAttribute.new(name: "obj", value: Node::Object.new(object_attributes: [
            Node::ObjectAttribute.new(name: "new", value: Node::Primitive.new(kind: "string"))
          ]))
        ]))
      ])

      expect(actual).to eq(expected)
    end

    it "parse array of strings" do
      actual = parser.parse_value("[string]")
      expected = Node::Array.new(value: Node::Primitive.new(kind: "string"))

      expect(actual).to eq(expected)
    end

    it "parse array of objects" do
      actual = parser.parse_value("[{ a: string }]")
      expected = Node::Array.new(value: Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "a", value: Node::Primitive.new(kind: "string"))
      ]))

      expect(actual).to eq(expected)
    end

    it "parse primitive" do
      actual = parser.parse_value("boolean")
      expected = Node::Primitive.new(kind: "boolean")

      expect(actual).to eq(expected)
    end

    it "parse entity" do
      expect { parser.parse_value("User") }.to raise_error(RuntimeError, "Unknown value: User")
    end

    describe "with some valid entities" do
      let(:user_entity) { OpenStruct.new({ name: "User" }) }
      let(:valid_entities) { [ user_entity ] }
      subject(:parser) { JSONSchemaParser.new(valid_entities) }

      it "can parse entity" do
        actual = parser.parse_value(user_entity.name)
        expected = Node::Entity.new(entity: user_entity)

        expect(actual).to eq(expected)
      end

      it "can raise if invalid name" do
        expect { parser.parse_value("Invalid") }.to raise_error(RuntimeError, "Unknown value: Invalid")
      end
    end
  end
end
