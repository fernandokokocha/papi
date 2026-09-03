require "rails_helper"
require "ostruct"

describe Schema::Parser, type: :model do
  subject(:parser) { Schema::Parser.new }

  describe "#parse_whole_value" do
    it "parse empty string" do
      actual = parser.parse_whole_value("")
      expected = Schema::Node::Nothing.new
      expect(actual).to eq(expected)
    end

    it "parse a present output like any other value" do
      actual = parser.parse_whole_value("[string]")
      expected = Schema::Node::Array.new(value: Schema::Node::Primitive.new(kind: "string"))
      expect(actual).to eq(expected)
    end
  end

  describe "#parse_value" do
    it "rejects an empty string" do
      expect { parser.parse_value("") }
        .to raise_error(RuntimeError, "Empty value: only a whole value may be empty")
    end

    it "rejects an empty object attribute" do
      expect { parser.parse_value("{a:}") }
        .to raise_error(RuntimeError, "Empty value: only a whole value may be empty")
    end

    it "rejects an empty array element" do
      expect { parser.parse_value("[]") }
        .to raise_error(RuntimeError, "Empty value: only a whole value may be empty")
    end

    it "rejects an empty union branch" do
      expect { parser.parse_value("(string|)") }
        .to raise_error(RuntimeError, "Empty value: only a whole value may be empty")
    end

    it "parse {}" do
      actual = parser.parse_value("{}")
      expected = Schema::Node::Object.new
      expect(actual).to eq(expected)
    end

    it "parse { a: string }" do
      actual = parser.parse_value("{ a: string }")
      expected = Schema::Node::Object.new(object_attributes: [
        Schema::Node::ObjectAttribute.new(name: "a", value: Schema::Node::Primitive.new(kind: "string"))
      ])

      expect(actual).to eq(expected)
    end

    it "parse { a: number }" do
      actual = parser.parse_value("{ a: number }")
      expected = Schema::Node::Object.new(object_attributes: [
        Schema::Node::ObjectAttribute.new(name: "a", value: Schema::Node::Primitive.new(kind: "number"))
      ])

      expect(actual).to eq(expected)
    end

    it "parse { nickname?: string }" do
      actual = parser.parse_value("{ nickname?: string }")
      expected = Schema::Node::Object.new(object_attributes: [
        Schema::Node::ObjectAttribute.new(name: "nickname", value: Schema::Node::Primitive.new(kind: "string"), optional: true)
      ])

      expect(actual).to eq(expected)
    end

    it "treats an attribute without the suffix as required" do
      actual = parser.parse_value("{ nickname: string }")

      expect(actual.object_attributes.first.optional).to eq(false)
    end

    it "round-trips the optional suffix through serialize" do
      actual = parser.parse_value("{ id: number, nickname?: string }")

      expect(actual.serialize).to eq("{id:number,nickname?:string}")
    end

    it "parse { a: string, b: number }" do
      actual = parser.parse_value("{ a: string, b: number }")
      expected = Schema::Node::Object.new(object_attributes: [
        Schema::Node::ObjectAttribute.new(name: "a", value: Schema::Node::Primitive.new(kind: "string")),
        Schema::Node::ObjectAttribute.new(name: "b", value: Schema::Node::Primitive.new(kind: "number"))
      ])

      expect(actual).to eq(expected)
    end

    it "parse { a: { b: string } }" do
      actual = parser.parse_value("{ a: { b: string } }")
      expected = Schema::Node::Object.new(object_attributes: [
        Schema::Node::ObjectAttribute.new(name: "a", value: Schema::Node::Object.new(object_attributes: [
          Schema::Node::ObjectAttribute.new(name: "b", value: Schema::Node::Primitive.new(kind: "string"))
        ]))
      ])

      expect(actual).to eq(expected)
    end

    it "parse { a: { b: string, c: number } }" do
      actual = parser.parse_value("{ a: { b: string, c: number } }")
      expected = Schema::Node::Object.new(object_attributes: [
        Schema::Node::ObjectAttribute.new(name: "a", value: Schema::Node::Object.new(object_attributes: [
          Schema::Node::ObjectAttribute.new(name: "b", value: Schema::Node::Primitive.new(kind: "string")),
          Schema::Node::ObjectAttribute.new(name: "c", value: Schema::Node::Primitive.new(kind: "number"))
        ]))
      ])

      expect(actual).to eq(expected)
    end

    it "parse real life problem" do
      actual = parser.parse_value("{name:string,child:{first_name:string,last_name:string,third_name:number},elo:string}")
      expected = Schema::Node::Object.new(object_attributes: [
        Schema::Node::ObjectAttribute.new(name: "name", value: Schema::Node::Primitive.new(kind: "string")),
        Schema::Node::ObjectAttribute.new(name: "child", value: Schema::Node::Object.new(object_attributes: [
          Schema::Node::ObjectAttribute.new(name: "first_name", value: Schema::Node::Primitive.new(kind: "string")),
          Schema::Node::ObjectAttribute.new(name: "last_name", value: Schema::Node::Primitive.new(kind: "string")),
          Schema::Node::ObjectAttribute.new(name: "third_name", value: Schema::Node::Primitive.new(kind: "number"))
        ])),
        Schema::Node::ObjectAttribute.new(name: "elo", value: Schema::Node::Primitive.new(kind: "string"))
      ])

      expect(actual).to eq(expected)
    end

    it "parse three levels of nesting" do
      actual = parser.parse_value("{name:string,child:{first_name:string,last_name:string,obj:{new:string}}}")
      expected = Schema::Node::Object.new(object_attributes: [
        Schema::Node::ObjectAttribute.new(name: "name", value: Schema::Node::Primitive.new(kind: "string")),
        Schema::Node::ObjectAttribute.new(name: "child", value: Schema::Node::Object.new(object_attributes: [
          Schema::Node::ObjectAttribute.new(name: "first_name", value: Schema::Node::Primitive.new(kind: "string")),
          Schema::Node::ObjectAttribute.new(name: "last_name", value: Schema::Node::Primitive.new(kind: "string")),
          Schema::Node::ObjectAttribute.new(name: "obj", value: Schema::Node::Object.new(object_attributes: [
            Schema::Node::ObjectAttribute.new(name: "new", value: Schema::Node::Primitive.new(kind: "string"))
          ]))
        ]))
      ])

      expect(actual).to eq(expected)
    end

    it "parse array of strings" do
      actual = parser.parse_value("[string]")
      expected = Schema::Node::Array.new(value: Schema::Node::Primitive.new(kind: "string"))

      expect(actual).to eq(expected)
    end

    it "parse array of objects" do
      actual = parser.parse_value("[{ a: string }]")
      expected = Schema::Node::Array.new(value: Schema::Node::Object.new(object_attributes: [
        Schema::Node::ObjectAttribute.new(name: "a", value: Schema::Node::Primitive.new(kind: "string"))
      ]))

      expect(actual).to eq(expected)
    end

    it "parse primitive" do
      actual = parser.parse_value("boolean")
      expected = Schema::Node::Primitive.new(kind: "boolean")

      expect(actual).to eq(expected)
    end

    it "parse null" do
      actual = parser.parse_value("null")
      expected = Schema::Node::Primitive.new(kind: "null")

      expect(actual).to eq(expected)
    end

    it "parse entity" do
      expect { parser.parse_value("User") }.to raise_error(RuntimeError, "Unknown value: User")
    end

    it "does not read a name merely starting with a primitive kind as that primitive" do
      expect { parser.parse_value("numberOfItems") }.to raise_error(RuntimeError, "Unknown value: numberOfItems")
      expect { parser.parse_value("stringify") }.to raise_error(RuntimeError, "Unknown value: stringify")
      expect { parser.parse_value("nullable") }.to raise_error(RuntimeError, "Unknown value: nullable")
    end

    describe "with some valid entities" do
      let(:user_entity) { OpenStruct.new({ name: "User" }) }
      let(:count_entity) { OpenStruct.new({ name: "numberOfItems" }) }
      let(:valid_entities) { [ user_entity, count_entity ] }
      subject(:parser) { Schema::Parser.new(valid_entities) }

      it "can parse entity" do
        actual = parser.parse_value(user_entity.name)
        expected = Schema::Node::Entity.new(entity: user_entity)

        expect(actual).to eq(expected)
      end

      it "can parse an entity whose name starts with a primitive kind" do
        actual = parser.parse_value("{count:numberOfItems}")
        expected = Schema::Node::Object.new(object_attributes: [
          Schema::Node::ObjectAttribute.new(name: "count", value: Schema::Node::Entity.new(entity: count_entity))
        ])

        expect(actual).to eq(expected)
      end

      it "can raise if invalid name" do
        expect { parser.parse_value("Invalid") }.to raise_error(RuntimeError, "Unknown value: Invalid")
      end
    end
  end
end
