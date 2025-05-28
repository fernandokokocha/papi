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

  # # object to object
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

  #
  #   test "array of strings -> same thing" do
  #     value1 = FactoryBot.create(:array_node, value: FactoryBot.create(:primitive_node, kind: "string"))
  #     value2 = FactoryBot.create(:array_node, value: FactoryBot.create(:primitive_node, kind: "string"))
  #
  #     diff = Diff.new.diff(value1, value2, 0)
  #     expected = [
  #       DiffLine.new("[", :no_change, 0),
  #       DiffLine.new("  string", :no_change, 2),
  #       DiffLine.new("]", :no_change, 0)
  #     ]
  #     assert_equal expected, diff.before
  #     expected = [
  #       DiffLine.new("[", :no_change, 0),
  #       DiffLine.new("  string", :no_change, 2),
  #       DiffLine.new("]", :no_change, 0)
  #     ]
  #     assert_equal expected, diff.after
  #   end
  #
  #   test "array of strings -> array of numbers" do
  #     value1 = FactoryBot.create(:array_node, value: FactoryBot.create(:primitive_node, kind: "string"))
  #     value2 = FactoryBot.create(:array_node, value: FactoryBot.create(:primitive_node, kind: "number"))
  #
  #     diff = Diff.new.diff(value1, value2, 0)
  #     expected = [
  #       DiffLine.new("[", :no_change, 0),
  #       DiffLine.new("  string", :type_changed, 2),
  #       DiffLine.new("]", :no_change, 0)
  #     ]
  #     assert_equal expected, diff.before
  #     expected = [
  #       DiffLine.new("[", :no_change, 0),
  #       DiffLine.new("  number", :type_changed, 2),
  #       DiffLine.new("]", :no_change, 0)
  #     ]
  #     assert_equal expected, diff.after
  #   end
  #
  #   # test "array of strings -> array of object" do
  #   test "bartek" do
  #     value1 = FactoryBot.create(:array_node, value: FactoryBot.create(:primitive_node, kind: "string"))
  #     value2 = FactoryBot.create(:array_node, value:
  #       FactoryBot.create(:object_node, object_attributes: [
  #         FactoryBot.create(:object_attribute, name: "name")
  #       ]
  #       ))
  #
  #     diff = Diff.new.diff(value1, value2, 0)
  #     # debugger
  #     expected = [
  #       DiffLine.new("[", :no_change, 0),
  #       DiffLine.new("  string", :type_changed, 2),
  #       DiffLine.new("", :blank, 0),
  #       DiffLine.new("", :blank, 0),
  #       DiffLine.new("]", :no_change, 0)
  #     ]
  #     assert_equal expected, diff.before
  #     expected = [
  #       DiffLine.new("[", :no_change, 0),
  #       DiffLine.new("  {", :type_changed, 2),
  #       DiffLine.new("    name: string", :type_changed, 4),
  #       DiffLine.new("  }", :type_changed, 2),
  #       DiffLine.new("]", :no_change, 0)
  #     ]
  #     assert_equal expected, diff.after
  #   end
end
