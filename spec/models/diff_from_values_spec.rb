require "rails_helper"

describe Diff::FromValues, type: :model do
  context "from primitive" do
    it "string -> string" do
      value1 = Node::Primitive.new(kind: "string")
      value2 = Node::Primitive.new(kind: "string")

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("string", :no_change, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("string", :no_change, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "string -> number" do
      value1 = Node::Primitive.new(kind: "string")
      value2 = Node::Primitive.new(kind: "number")

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("string", :type_changed, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("number", :type_changed, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "string -> object" do
      value1 = Node::Primitive.new(kind: "string")
      value2 = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "name", value: Node::Primitive.new(kind: "string"))
      ])

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("string", :type_changed, 0),
                                   Diff::Line.new("", :blank, 0),
                                   Diff::Line.new("", :blank, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("{", :type_changed, 0),
                                   Diff::Line.new("name: string", :type_changed, 1),
                                   Diff::Line.new("}", :type_changed, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "string -> object with parent" do
      value1 = Node::Primitive.new(kind: "string")
      value2 = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "name", value: Node::Primitive.new(kind: "string"))
      ])

      diff = Diff::FromValues.new(value1, value2)
      diff.add_parent("parent")
      expected = Diff::Lines.new([
                                   Diff::Line.new("parent: string", :type_changed, 0),
                                   Diff::Line.new("", :blank, 0),
                                   Diff::Line.new("", :blank, 0),
                                   Diff::Line.new("", :blank, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("parent:", :type_changed, 0),
                                   Diff::Line.new("{", :type_changed, 0),
                                   Diff::Line.new("name: string", :type_changed, 1),
                                   Diff::Line.new("}", :type_changed, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "string -> array" do
      value1 = Node::Primitive.new(kind: "string")
      value2 = Node::Array.new(value: Node::Primitive.new(kind: "number"))

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("string", :type_changed, 0),
                                   Diff::Line.new("", :blank, 0),
                                   Diff::Line.new("", :blank, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("[", :type_changed, 0),
                                   Diff::Line.new("number", :type_changed, 1),
                                   Diff::Line.new("]", :type_changed, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "primitive -> nothing" do
      value1 = Node::Primitive.new(kind: "string")
      value2 = Node::Nothing.new

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("string", :removed, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("", :blank, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "primitive -> entity" do
      value1 = Node::Primitive.new(kind: "string")
      entity = Entity.new(name: "Resource")
      value2 = Node::Entity.new(entity: entity)

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("string", :type_changed, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("Resource", :type_changed, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end
  end

  context "from object" do
    it "object -> string" do
      value1 = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "name", value: Node::Primitive.new(kind: "string"))
      ])
      value2 = Node::Primitive.new(kind: "string")

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("{", :type_changed, 0),
                                   Diff::Line.new("name: string", :type_changed, 1),
                                   Diff::Line.new("}", :type_changed, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("string", :type_changed, 0),
                                   Diff::Line.new("", :blank, 0),
                                   Diff::Line.new("", :blank, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "empty object -> empty object" do
      value1 = Node::Object.new
      value2 = Node::Object.new

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("{", :no_change, 0),
                                   Diff::Line.new("}", :no_change, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expect(diff.after).to eq(expected)
    end

    it "empty object -> object with one attr" do
      value1 = Node::Object.new
      value2 = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "name", value: Node::Primitive.new(kind: "string"))
      ])

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("{", :no_change, 0),
                                   Diff::Line.new("", :blank, 0),
                                   Diff::Line.new("}", :no_change, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("{", :no_change, 0),
                                   Diff::Line.new("name: string", :added, 1),
                                   Diff::Line.new("}", :no_change, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "object with one attr -> empty object" do
      value1 = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "name", value: Node::Primitive.new(kind: "string"))
      ])
      value2 = Node::Object.new

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("{", :no_change, 0),
                                   Diff::Line.new("name: string", :removed, 1),
                                   Diff::Line.new("}", :no_change, 0)
                                 ])
      expect(diff.before).to eq(expected)

      expected = Diff::Lines.new([
                                   Diff::Line.new("{", :no_change, 0),
                                   Diff::Line.new("", :blank, 0),
                                   Diff::Line.new("}", :no_change, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "object with one attr -> object with different attr" do
      value1 = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "name", value: Node::Primitive.new(kind: "string"))
      ])

      value2 = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "city", value: Node::Primitive.new(kind: "string"))
      ])

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("{", :no_change, 0),
                                   Diff::Line.new("", :blank, 0),
                                   Diff::Line.new("name: string", :removed, 1),
                                   Diff::Line.new("}", :no_change, 0)
                                 ])

      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("{", :no_change, 0),
                                   Diff::Line.new("city: string", :added, 1),
                                   Diff::Line.new("", :blank, 0),
                                   Diff::Line.new("}", :no_change, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "object with one attr -> object with two attrs" do
      value1 = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "name", value: Node::Primitive.new(kind: "string"))
      ])
      value2 = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "name", value: Node::Primitive.new(kind: "string")),
        Node::ObjectAttribute.new(name: "city", value: Node::Primitive.new(kind: "string"))
      ])

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("{", :no_change, 0),
                                   Diff::Line.new("name: string", :no_change, 1),
                                   Diff::Line.new("", :blank, 0),
                                   Diff::Line.new("}", :no_change, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("{", :no_change, 0),
                                   Diff::Line.new("name: string", :no_change, 1),
                                   Diff::Line.new("city: string", :added, 1),
                                   Diff::Line.new("}", :no_change, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "object with one attr -> object with changed attr" do
      value1 = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "name", value: Node::Primitive.new(kind: "string"))
      ])

      value2 = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "name", value: Node::Primitive.new(kind: "number"))
      ])

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("{", :no_change, 0),
                                   Diff::Line.new("name: string", :type_changed, 1),
                                   Diff::Line.new("}", :no_change, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("{", :no_change, 0),
                                   Diff::Line.new("name: number", :type_changed, 1),
                                   Diff::Line.new("}", :no_change, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "nested object added one attr" do
      value1 = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "name", value: Node::Primitive.new(kind: "string")),
        Node::ObjectAttribute.new(name: "child", value:
          Node::Object.new(object_attributes: [
            Node::ObjectAttribute.new(name: "name", value: Node::Primitive.new(kind: "string"))
          ]))
      ])

      value2 = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "name", value: Node::Primitive.new(kind: "string")),
        Node::ObjectAttribute.new(name: "child", value:
          Node::Object.new(object_attributes: [
            Node::ObjectAttribute.new(name: "name", value: Node::Primitive.new(kind: "string")),
            Node::ObjectAttribute.new(name: "age", value: Node::Primitive.new(kind: "number"))
          ]))
      ])

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("{", :no_change, 0),
                                   Diff::Line.new("name: string", :no_change, 1),
                                   Diff::Line.new("child:", :no_change, 1),
                                   Diff::Line.new("{", :no_change, 1),
                                   Diff::Line.new("name: string", :no_change, 2),
                                   Diff::Line.new("", :blank, 0),
                                   Diff::Line.new("}", :no_change, 1),
                                   Diff::Line.new("}", :no_change, 0)
                                 ])

      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("{", :no_change, 0),
                                   Diff::Line.new("name: string", :no_change, 1),
                                   Diff::Line.new("child:", :no_change, 1),
                                   Diff::Line.new("{", :no_change, 1),
                                   Diff::Line.new("name: string", :no_change, 2),
                                   Diff::Line.new("age: number", :added, 2),
                                   Diff::Line.new("}", :no_change, 1),
                                   Diff::Line.new("}", :no_change, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "object -> array" do
      value1 = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "name", value: Node::Primitive.new(kind: "string"))
      ])
      value2 = Node::Array.new(value: Node::Primitive.new(kind: "string"))

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("{", :type_changed, 0),
                                   Diff::Line.new("name: string", :type_changed, 1),
                                   Diff::Line.new("}", :type_changed, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("[", :type_changed, 0),
                                   Diff::Line.new("string", :type_changed, 1),
                                   Diff::Line.new("]", :type_changed, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "object -> nothing" do
      value1 = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "name", value: Node::Primitive.new(kind: "string"))
      ])
      value2 = Node::Nothing.new

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("{", :removed, 0),
                                   Diff::Line.new("name: string", :removed, 1),
                                   Diff::Line.new("}", :removed, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("", :blank, 0),
                                   Diff::Line.new("", :blank, 0),
                                   Diff::Line.new("", :blank, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end
  end

  context "from array" do
    it "array of strings -> same thing" do
      value1 = Node::Array.new(value: Node::Primitive.new(kind: "string"))
      value2 = Node::Array.new(value: Node::Primitive.new(kind: "string"))

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("[", :no_change, 0),
                                   Diff::Line.new("string", :no_change, 1),
                                   Diff::Line.new("]", :no_change, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("[", :no_change, 0),
                                   Diff::Line.new("string", :no_change, 1),
                                   Diff::Line.new("]", :no_change, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "array of strings -> array of numbers" do
      value1 = Node::Array.new(value: Node::Primitive.new(kind: "string"))
      value2 = Node::Array.new(value: Node::Primitive.new(kind: "number"))

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("[", :no_change, 0),
                                   Diff::Line.new("string", :type_changed, 1),
                                   Diff::Line.new("]", :no_change, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("[", :no_change, 0),
                                   Diff::Line.new("number", :type_changed, 1),
                                   Diff::Line.new("]", :no_change, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "array of strings -> array of object" do
      value1 = Node::Array.new(value: Node::Primitive.new(kind: "string"))
      value2 = Node::Array.new(value:
        Node::Object.new(object_attributes: [
          Node::ObjectAttribute.new(name: "name", value: Node::Primitive.new(kind: "string"))
        ]
        ))

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("[", :no_change, 0),
                                   Diff::Line.new("string", :type_changed, 1),
                                   Diff::Line.new("", :blank, 0),
                                   Diff::Line.new("", :blank, 0),
                                   Diff::Line.new("]", :no_change, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("[", :no_change, 0),
                                   Diff::Line.new("{", :type_changed, 1),
                                   Diff::Line.new("name: string", :type_changed, 2),
                                   Diff::Line.new("}", :type_changed, 1),
                                   Diff::Line.new("]", :no_change, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "array -> object" do
      value1 = Node::Array.new(value: Node::Primitive.new(kind: "string"))
      value2 = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "name", value: Node::Primitive.new(kind: "string"))
      ])

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("[", :type_changed, 0),
                                   Diff::Line.new("string", :type_changed, 1),
                                   Diff::Line.new("]", :type_changed, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("{", :type_changed, 0),
                                   Diff::Line.new("name: string", :type_changed, 1),
                                   Diff::Line.new("}", :type_changed, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "array -> string" do
      value1 = Node::Array.new(value: Node::Primitive.new(kind: "number"))
      value2 = Node::Primitive.new(kind: "string")

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("[", :type_changed, 0),
                                   Diff::Line.new("number", :type_changed, 1),
                                   Diff::Line.new("]", :type_changed, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("string", :type_changed, 0),
                                   Diff::Line.new("", :blank, 0),
                                   Diff::Line.new("", :blank, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "array -> nothing" do
      value1 = Node::Array.new(value: Node::Primitive.new(kind: "string"))
      value2 = Node::Nothing.new

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("[", :removed, 0),
                                   Diff::Line.new("string", :removed, 1),
                                   Diff::Line.new("]", :removed, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("", :blank, 0),
                                   Diff::Line.new("", :blank, 0),
                                   Diff::Line.new("", :blank, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end
  end

  context "from nothing" do
    it "nothing -> primitive" do
      value1 = Node::Nothing.new
      value2 = Node::Primitive.new(kind: "string")

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("", :blank, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("string", :added, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "nothing -> object" do
      value1 = Node::Nothing.new
      value2 = Node::Object.new(object_attributes: [
        Node::ObjectAttribute.new(name: "name", value: Node::Primitive.new(kind: "string"))
      ])

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("", :blank, 0),
                                   Diff::Line.new("", :blank, 0),
                                   Diff::Line.new("", :blank, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("{", :added, 0),
                                   Diff::Line.new("name: string", :added, 1),
                                   Diff::Line.new("}", :added, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "nothing -> array" do
      value1 = Node::Nothing.new
      value2 = Node::Array.new(value: Node::Primitive.new(kind: "string"))

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("", :blank, 0),
                                   Diff::Line.new("", :blank, 0),
                                   Diff::Line.new("", :blank, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("[", :added, 0),
                                   Diff::Line.new("string", :added, 1),
                                   Diff::Line.new("]", :added, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "nothing -> nothing" do
      value1 = Node::Nothing.new
      value2 = Node::Nothing.new

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([])
      expect(diff.before).to eq(expected)
      expect(diff.after).to eq(expected)
    end

    it "nothing -> entity" do
      value1 = Node::Nothing.new
      entity = Entity.new(name: "Resource")
      value2 = Node::Entity.new(entity: entity)

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("", :blank, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("Resource", :added, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end
  end

  context "from entity" do
    it "entity -> nothing" do
      entity = Entity.new(name: "Resource")
      value1 = Node::Entity.new(entity: entity)
      value2 = Node::Nothing.new

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("Resource", :removed, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("", :blank, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end

    it "entity -> primitive" do
      entity = Entity.new(name: "Resource")
      value1 = Node::Entity.new(entity: entity)
      value2 = Node::Primitive.new(kind: "string")

      diff = Diff::FromValues.new(value1, value2)
      expected = Diff::Lines.new([
                                   Diff::Line.new("Resource", :type_changed, 0)
                                 ])
      expect(diff.before).to eq(expected)
      expected = Diff::Lines.new([
                                   Diff::Line.new("string", :type_changed, 0)
                                 ])
      expect(diff.after).to eq(expected)
    end
  end
end
