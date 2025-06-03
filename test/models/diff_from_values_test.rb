require "test_helper"

class DiffFromValuesTest < ActiveSupport::TestCase
  # primitive to primitive
  test "string -> string" do
    value1 = FactoryBot.create(:primitive_node, kind: "string")
    value2 = FactoryBot.create(:primitive_node, kind: "string")

    diff = Diff::FromValues.new(value1, value2)
    expected = Diff::Lines.new([
                                 Diff::Line.new("string", :no_change, 0)
                               ])
    assert_equal expected, diff.before
    expected = Diff::Lines.new([
                                 Diff::Line.new("string", :no_change, 0)
                               ])
    assert_equal expected, diff.after
  end

  test "string -> number" do
    value1 = FactoryBot.create(:primitive_node, kind: "string")
    value2 = FactoryBot.create(:primitive_node, kind: "number")

    diff = Diff::FromValues.new(value1, value2)
    expected = Diff::Lines.new([
                                 Diff::Line.new("string", :type_changed, 0)
                               ])
    assert_equal expected, diff.before
    expected = Diff::Lines.new([
                                 Diff::Line.new("number", :type_changed, 0)
                               ])
    assert_equal expected, diff.after
  end

  # primitive to object
  test "string -> object" do
    value1 = FactoryBot.create(:primitive_node, kind: "string")
    value2 = FactoryBot.create(:object_node, object_attributes: [
      FactoryBot.create(:object_attribute, name: "name")
    ])

    diff = Diff::FromValues.new(value1, value2)
    expected = Diff::Lines.new([
                                 Diff::Line.new("string", :type_changed, 0),
                                 Diff::Line.new("", :blank, 0),
                                 Diff::Line.new("", :blank, 0)
                               ])
    assert_equal expected, diff.before
    expected = Diff::Lines.new([
                                 Diff::Line.new("{", :type_changed, 0),
                                 Diff::Line.new("name: string", :type_changed, 1),
                                 Diff::Line.new("}", :type_changed, 0)
                               ])
    assert_equal expected, diff.after
  end

  test "string -> object with parent" do
    value1 = FactoryBot.create(:primitive_node, kind: "string")
    value2 = FactoryBot.create(:object_node, object_attributes: [
      FactoryBot.create(:object_attribute, name: "name")
    ])

    diff = Diff::FromValues.new(value1, value2)
    diff.add_parent("parent")
    expected = Diff::Lines.new([
                                 Diff::Line.new("parent: string", :type_changed, 0),
                                 Diff::Line.new("", :blank, 0),
                                 Diff::Line.new("", :blank, 0),
                                 Diff::Line.new("", :blank, 0)
                               ])
    assert_equal expected, diff.before
    expected = Diff::Lines.new([
                                 Diff::Line.new("parent:", :type_changed, 0),
                                 Diff::Line.new("{", :type_changed, 0),
                                 Diff::Line.new("name: string", :type_changed, 1),
                                 Diff::Line.new("}", :type_changed, 0)
                               ])
    assert_equal expected, diff.after
  end

  # primitive to array
  test "string -> array" do
    value1 = FactoryBot.create(:primitive_node, kind: "string")
    value2 = FactoryBot.create(:array_node, value: FactoryBot.create(:primitive_node, kind: "number"))

    diff = Diff::FromValues.new(value1, value2)
    expected = Diff::Lines.new([
                                 Diff::Line.new("string", :type_changed, 0),
                                 Diff::Line.new("", :blank, 0),
                                 Diff::Line.new("", :blank, 0)
                               ])
    assert_equal expected, diff.before
    expected = Diff::Lines.new([
                                 Diff::Line.new("[", :type_changed, 0),
                                 Diff::Line.new("number", :type_changed, 1),
                                 Diff::Line.new("]", :type_changed, 0)
                               ])
    assert_equal expected, diff.after
  end

  # object to primitive
  test "object -> string" do
    value1 = FactoryBot.create(:object_node, object_attributes: [
      FactoryBot.create(:object_attribute, name: "name")
    ])
    value2 = FactoryBot.create(:primitive_node, kind: "string")

    diff = Diff::FromValues.new(value1, value2)
    expected = Diff::Lines.new([
                                 Diff::Line.new("{", :type_changed, 0),
                                 Diff::Line.new("name: string", :type_changed, 1),
                                 Diff::Line.new("}", :type_changed, 0)
                               ])
    assert_equal expected, diff.before
    expected = Diff::Lines.new([
                                 Diff::Line.new("string", :type_changed, 0),
                                 Diff::Line.new("", :blank, 0),
                                 Diff::Line.new("", :blank, 0)
                               ])
    assert_equal expected, diff.after
  end

  # object to object
  test "empty object -> empty object" do
    value1 = FactoryBot.create(:object_node)
    value2 = FactoryBot.create(:object_node)

    diff = Diff::FromValues.new(value1, value2)
    expected = Diff::Lines.new([
                                 Diff::Line.new("{", :no_change, 0),
                                 Diff::Line.new("}", :no_change, 0)
                               ])
    assert_equal expected, diff.before
    assert_equal expected, diff.after
  end

  test "empty object -> object with one attr" do
    value1 = FactoryBot.create(:object_node)
    value2 = FactoryBot.create(:object_node, object_attributes: [
      FactoryBot.create(:object_attribute, name: "name")
    ])

    diff = Diff::FromValues.new(value1, value2)
    expected = Diff::Lines.new([
                                 Diff::Line.new("{", :no_change, 0),
                                 Diff::Line.new("", :blank, 0),
                                 Diff::Line.new("}", :no_change, 0)
                               ])
    assert_equal expected, diff.before
    expected = Diff::Lines.new([
                                 Diff::Line.new("{", :no_change, 0),
                                 Diff::Line.new("name: string", :added, 1),
                                 Diff::Line.new("}", :no_change, 0)
                               ])
    assert_equal expected, diff.after
  end

  test "object with one attr -> empty object" do
    value1 = FactoryBot.create(:object_node, object_attributes: [
      FactoryBot.create(:object_attribute, name: "name")
    ])
    value2 = FactoryBot.create(:object_node)

    diff = Diff::FromValues.new(value1, value2)
    expected = Diff::Lines.new([
                                 Diff::Line.new("{", :no_change, 0),
                                 Diff::Line.new("name: string", :removed, 1),
                                 Diff::Line.new("}", :no_change, 0)
                               ])
    assert_equal expected, diff.before

    expected = Diff::Lines.new([
                                 Diff::Line.new("{", :no_change, 0),
                                 Diff::Line.new("", :blank, 0),
                                 Diff::Line.new("}", :no_change, 0)
                               ])
    assert_equal expected, diff.after
  end

  test "object with one attr -> object with different attr" do
    value1 = FactoryBot.create(:object_node, object_attributes: [
      FactoryBot.create(:object_attribute, name: "name")
    ])

    value2 = FactoryBot.create(:object_node, object_attributes: [
      FactoryBot.create(:object_attribute, name: "city")
    ])

    diff = Diff::FromValues.new(value1, value2)
    expected = Diff::Lines.new([
                                 Diff::Line.new("{", :no_change, 0),
                                 Diff::Line.new("", :blank, 0),
                                 Diff::Line.new("name: string", :removed, 1),
                                 Diff::Line.new("}", :no_change, 0)
                               ])
    assert_equal expected, diff.before
    expected = Diff::Lines.new([
                                 Diff::Line.new("{", :no_change, 0),
                                 Diff::Line.new("city: string", :added, 1),
                                 Diff::Line.new("", :blank, 0),
                                 Diff::Line.new("}", :no_change, 0)
                               ])
    assert_equal expected, diff.after
  end

  test "object with one attr -> object with two attrs" do
    value1 = FactoryBot.create(:object_node, object_attributes: [
      FactoryBot.create(:object_attribute, name: "name")
    ])
    value2 = FactoryBot.create(:object_node, object_attributes: [
      FactoryBot.create(:object_attribute, name: "name"),
      FactoryBot.create(:object_attribute, name: "city")
    ])

    diff = Diff::FromValues.new(value1, value2)
    expected = Diff::Lines.new([
                                 Diff::Line.new("{", :no_change, 0),
                                 Diff::Line.new("name: string", :no_change, 1),
                                 Diff::Line.new("", :blank, 0),
                                 Diff::Line.new("}", :no_change, 0)
                               ])
    assert_equal expected, diff.before
    expected = Diff::Lines.new([
                                 Diff::Line.new("{", :no_change, 0),
                                 Diff::Line.new("name: string", :no_change, 1),
                                 Diff::Line.new("city: string", :added, 1),
                                 Diff::Line.new("}", :no_change, 0)
                               ])
    assert_equal expected, diff.after
  end

  test "object with one attr -> object with changed attr" do
    value1 = FactoryBot.create(:object_node, object_attributes: [
      FactoryBot.create(:object_attribute, name: "name")
    ])

    value2 = FactoryBot.create(:object_node, object_attributes: [
      FactoryBot.create(:object_attribute, name: "name", value: FactoryBot.create(:primitive_node, kind: "number"))
    ])

    diff = Diff::FromValues.new(value1, value2)
    expected = Diff::Lines.new([
                                 Diff::Line.new("{", :no_change, 0),
                                 Diff::Line.new("name: string", :type_changed, 1),
                                 Diff::Line.new("}", :no_change, 0)
                               ])
    assert_equal expected, diff.before
    expected = Diff::Lines.new([
                                 Diff::Line.new("{", :no_change, 0),
                                 Diff::Line.new("name: number", :type_changed, 1),
                                 Diff::Line.new("}", :no_change, 0)
                               ])
    assert_equal expected, diff.after
  end

  test "nested object added one attr" do
    value1 = FactoryBot.create(:object_node, object_attributes: [
      FactoryBot.create(:object_attribute, name: "name"),
      FactoryBot.create(:object_attribute, name: "child", value:
        FactoryBot.create(:object_node, object_attributes: [
          FactoryBot.create(:object_attribute, name: "name")
        ]))
    ])

    value2 = FactoryBot.create(:object_node, object_attributes: [
      FactoryBot.create(:object_attribute, name: "name"),
      FactoryBot.create(:object_attribute, name: "child", value:
        FactoryBot.create(:object_node, object_attributes: [
          FactoryBot.create(:object_attribute, name: "name"),
          FactoryBot.create(:object_attribute, name: "age", value:
            FactoryBot.create(:primitive_node, kind: "number"))
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

    assert_equal expected, diff.before
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
    assert_equal expected, diff.after
  end

  # object to array
  test "object -> array" do
    value1 = FactoryBot.create(:object_node, object_attributes: [
      FactoryBot.create(:object_attribute, name: "name")
    ])
    value2 = FactoryBot.create(:array_node, value: FactoryBot.create(:primitive_node, kind: "string"))

    diff = Diff::FromValues.new(value1, value2)
    expected = Diff::Lines.new([
                                 Diff::Line.new("{", :type_changed, 0),
                                 Diff::Line.new("name: string", :type_changed, 1),
                                 Diff::Line.new("}", :type_changed, 0)
                               ])
    assert_equal expected, diff.before
    expected = Diff::Lines.new([
                                 Diff::Line.new("[", :type_changed, 0),
                                 Diff::Line.new("string", :type_changed, 1),
                                 Diff::Line.new("]", :type_changed, 0)
                               ])
    assert_equal expected, diff.after
  end

  # array to array
  test "array of strings -> same thing" do
    value1 = FactoryBot.create(:array_node, value: FactoryBot.create(:primitive_node, kind: "string"))
    value2 = FactoryBot.create(:array_node, value: FactoryBot.create(:primitive_node, kind: "string"))

    diff = Diff::FromValues.new(value1, value2)
    expected = Diff::Lines.new([
                                 Diff::Line.new("[", :no_change, 0),
                                 Diff::Line.new("string", :no_change, 1),
                                 Diff::Line.new("]", :no_change, 0)
                               ])
    assert_equal expected, diff.before
    expected = Diff::Lines.new([
                                 Diff::Line.new("[", :no_change, 0),
                                 Diff::Line.new("string", :no_change, 1),
                                 Diff::Line.new("]", :no_change, 0)
                               ])
    assert_equal expected, diff.after
  end

  test "array of strings -> array of numbers" do
    value1 = FactoryBot.create(:array_node, value: FactoryBot.create(:primitive_node, kind: "string"))
    value2 = FactoryBot.create(:array_node, value: FactoryBot.create(:primitive_node, kind: "number"))

    diff = Diff::FromValues.new(value1, value2)
    expected = Diff::Lines.new([
                                 Diff::Line.new("[", :no_change, 0),
                                 Diff::Line.new("string", :type_changed, 1),
                                 Diff::Line.new("]", :no_change, 0)
                               ])
    assert_equal expected, diff.before
    expected = Diff::Lines.new([
                                 Diff::Line.new("[", :no_change, 0),
                                 Diff::Line.new("number", :type_changed, 1),
                                 Diff::Line.new("]", :no_change, 0)
                               ])
    assert_equal expected, diff.after
  end

  test "array of strings -> array of object" do
    value1 = FactoryBot.create(:array_node, value: FactoryBot.create(:primitive_node, kind: "string"))
    value2 = FactoryBot.create(:array_node, value:
      FactoryBot.create(:object_node, object_attributes: [
        FactoryBot.create(:object_attribute, name: "name")
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
    assert_equal expected, diff.before
    expected = Diff::Lines.new([
                                 Diff::Line.new("[", :no_change, 0),
                                 Diff::Line.new("{", :type_changed, 1),
                                 Diff::Line.new("name: string", :type_changed, 2),
                                 Diff::Line.new("}", :type_changed, 1),
                                 Diff::Line.new("]", :no_change, 0)
                               ])
    assert_equal expected, diff.after
  end

  # array to object
  test "array -> object" do
    value1 = FactoryBot.create(:array_node, value: FactoryBot.create(:primitive_node, kind: "string"))
    value2 = FactoryBot.create(:object_node, object_attributes: [
      FactoryBot.create(:object_attribute, name: "name")
    ])

    diff = Diff::FromValues.new(value1, value2)
    expected = Diff::Lines.new([
                                 Diff::Line.new("[", :type_changed, 0),
                                 Diff::Line.new("string", :type_changed, 1),
                                 Diff::Line.new("]", :type_changed, 0)
                               ])
    assert_equal expected, diff.before
    expected = Diff::Lines.new([
                                 Diff::Line.new("{", :type_changed, 0),
                                 Diff::Line.new("name: string", :type_changed, 1),
                                 Diff::Line.new("}", :type_changed, 0)
                               ])
    assert_equal expected, diff.after
  end

  # array to primitive
  test "array -> string" do
    value1 = FactoryBot.create(:array_node, value: FactoryBot.create(:primitive_node, kind: "number"))
    value2 = FactoryBot.create(:primitive_node, kind: "string")

    diff = Diff::FromValues.new(value1, value2)
    expected = Diff::Lines.new([
                                 Diff::Line.new("[", :type_changed, 0),
                                 Diff::Line.new("number", :type_changed, 1),
                                 Diff::Line.new("]", :type_changed, 0)
                               ])
    assert_equal expected, diff.before
    expected = Diff::Lines.new([
                                 Diff::Line.new("string", :type_changed, 0),
                                 Diff::Line.new("", :blank, 0),
                                 Diff::Line.new("", :blank, 0)
                               ])
    assert_equal expected, diff.after
  end
end
