require "test_helper"

class DiffTest < ActiveSupport::TestCase
  test "nil -> empty object" do
    endpoint1 = nil
    endpoint2 = FactoryBot.create(:endpoint)

    diff = Diff.new(endpoint1, endpoint2)
    expected = [
      DiffLine.new("", :blank, 0),
      DiffLine.new("", :blank, 0)
    ]
    assert_equal expected, diff.before
    expected = [
      DiffLine.new("{", :added, 0),
      DiffLine.new("}", :added, 0)
    ]
    assert_equal expected, diff.after
  end

  test "empty object -> empty object" do
    endpoint1 = FactoryBot.create(:endpoint)
    endpoint2 = FactoryBot.create(:endpoint)

    diff = Diff.new(endpoint1, endpoint2)
    expected = [
      DiffLine.new("{", :no_change, 0),
      DiffLine.new("}", :no_change, 0)
    ]
    assert_equal expected, diff.before
    assert_equal expected, diff.after
  end

  test "empty object -> object with one attr" do
    endpoint1 = FactoryBot.create(:endpoint)
    endpoint2 = FactoryBot.create(:endpoint, endpoint_root:
      FactoryBot.create(:object_node, object_attributes: [
        FactoryBot.create(:object_attribute, name: "name")
      ])
    )

    diff = Diff.new(endpoint1, endpoint2)
    expected = [
      DiffLine.new("{", :no_change, 0),
      DiffLine.new("", :blank, 0),
      DiffLine.new("}", :no_change, 0)
    ]
    assert_equal expected, diff.before
    expected = [
      DiffLine.new("{", :no_change, 0),
      DiffLine.new("  name: string", :added, 2),
      DiffLine.new("}", :no_change, 0)
    ]
    assert_equal expected, diff.after
  end

  test "object with one attr -> empty object" do
    endpoint1 = FactoryBot.create(:endpoint, endpoint_root:
      FactoryBot.create(:object_node, object_attributes: [
        FactoryBot.create(:object_attribute, name: "name")
      ])
    )
    endpoint2 = FactoryBot.create(:endpoint)

    diff = Diff.new(endpoint1, endpoint2)
    expected = [
      DiffLine.new("{", :no_change, 0),
      DiffLine.new("  name: string", :removed, 2),
      DiffLine.new("}", :no_change, 0)
    ]
    assert_equal expected, diff.before

    expected = [
      DiffLine.new("{", :no_change, 0),
      DiffLine.new("", :blank, 0),
      DiffLine.new("}", :no_change, 0)
    ]
    assert_equal expected, diff.after
  end

  test "object with one attr -> object with different attr" do
    endpoint1 = FactoryBot.create(:endpoint, endpoint_root:
      FactoryBot.create(:object_node, object_attributes: [
        FactoryBot.create(:object_attribute, name: "name")
      ])
    )
    endpoint2 = FactoryBot.create(:endpoint, endpoint_root:
      FactoryBot.create(:object_node, object_attributes: [
        FactoryBot.create(:object_attribute, name: "city")
      ])
    )

    diff = Diff.new(endpoint1, endpoint2)
    expected = [
      DiffLine.new("{", :no_change, 0),
      DiffLine.new("", :blank, 0),
      DiffLine.new("  name: string", :removed, 2),
      DiffLine.new("}", :no_change, 0)
    ]
    assert_equal expected, diff.before
    expected = [
      DiffLine.new("{", :no_change, 0),
      DiffLine.new("  city: string", :added, 2),
      DiffLine.new("", :blank, 0),
      DiffLine.new("}", :no_change, 0)
    ]
    assert_equal expected, diff.after
  end

  test "object with one attr -> object with two attrs" do
    endpoint1 = FactoryBot.create(:endpoint, endpoint_root:
      FactoryBot.create(:object_node, object_attributes: [
        FactoryBot.create(:object_attribute, name: "name")
      ])
    )
    endpoint2 = FactoryBot.create(:endpoint, endpoint_root:
      FactoryBot.create(:object_node, object_attributes: [
        FactoryBot.create(:object_attribute, name: "name"),
        FactoryBot.create(:object_attribute, name: "city")
      ])
    )

    diff = Diff.new(endpoint1, endpoint2)
    expected = [
      DiffLine.new("{", :no_change, 0),
      DiffLine.new("  name: string", :no_change, 2),
      DiffLine.new("", :blank, 0),
      DiffLine.new("}", :no_change, 0)
    ]
    assert_equal expected, diff.before
    expected = [
      DiffLine.new("{", :no_change, 0),
      DiffLine.new("  name: string", :no_change, 2),
      DiffLine.new("  city: string", :added, 2),
      DiffLine.new("}", :no_change, 0)
    ]
    assert_equal expected, diff.after
  end

  test "object with one attr -> object with changed attr" do
    endpoint1 = FactoryBot.create(:endpoint, endpoint_root:
      FactoryBot.create(:object_node, object_attributes: [
        FactoryBot.create(:object_attribute, name: "name")
      ])
    )
    endpoint2 = FactoryBot.create(:endpoint, endpoint_root:
      FactoryBot.create(:object_node, object_attributes: [
        FactoryBot.create(:object_attribute, name: "name", value: FactoryBot.create(:primitive_node, kind: "number"))
      ])
    )

    diff = Diff.new(endpoint1, endpoint2)
    expected = [
      DiffLine.new("{", :no_change, 0),
      DiffLine.new("  name: string", :type_changed, 2),
      DiffLine.new("}", :no_change, 0)
    ]
    assert_equal expected, diff.before
    expected = [
      DiffLine.new("{", :no_change, 0),
      DiffLine.new("  name: number", :type_changed, 2),
      DiffLine.new("}", :no_change, 0)
    ]
    assert_equal expected, diff.after
  end

  test "nested object added one attr" do
    endpoint1 = FactoryBot.create(:endpoint, endpoint_root:
      FactoryBot.create(:object_node, object_attributes: [
        FactoryBot.create(:object_attribute, name: "name"),
        FactoryBot.create(:object_attribute, name: "child", value:
          FactoryBot.create(:object_node, object_attributes: [
            FactoryBot.create(:object_attribute, name: "name")
          ]))
      ])
    )
    endpoint2 = FactoryBot.create(:endpoint, endpoint_root:
      FactoryBot.create(:object_node, object_attributes: [
        FactoryBot.create(:object_attribute, name: "name"),
        FactoryBot.create(:object_attribute, name: "child", value:
          FactoryBot.create(:object_node, object_attributes: [
            FactoryBot.create(:object_attribute, name: "name"),
            FactoryBot.create(:object_attribute, name: "age", value: FactoryBot.create(:primitive_node, kind: "number"))
          ]))
      ])
    )

    diff = Diff.new(endpoint1, endpoint2)
    expected = [
      DiffLine.new("{", :no_change, 0),
      DiffLine.new("  name: string", :no_change, 2),
      DiffLine.new("  child:", :no_change, 2),
      DiffLine.new("  {", :no_change, 2),
      DiffLine.new("    name: string", :no_change, 4),
      DiffLine.new("", :blank, 0),
      DiffLine.new("  }", :no_change, 2),
      DiffLine.new("}", :no_change, 0)
    ]
    assert_equal expected, diff.before
    expected = [
      DiffLine.new("{", :no_change, 0),
      DiffLine.new("  name: string", :no_change, 2),
      DiffLine.new("  child:", :no_change, 2),
      DiffLine.new("  {", :no_change, 2),
      DiffLine.new("    name: string", :no_change, 4),
      DiffLine.new("    age: number", :added, 4),
      DiffLine.new("  }", :no_change, 2),
      DiffLine.new("}", :no_change, 0)
    ]
    assert_equal expected, diff.after
  end
end
