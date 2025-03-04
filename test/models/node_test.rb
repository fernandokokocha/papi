require "test_helper"

class NodeTest < ActiveSupport::TestCase
  test "empty object" do
    o = FactoryBot.create(:object_node)

    expected = %w[{ }]
    assert_equal(expected, o.lines(0))
  end

  test "one attr" do
    o = FactoryBot.create(:object_node)
    FactoryBot.create(:object_attribute, name: "name", parent: o)
    expected = [ "{", "  name: string", "}" ]

    assert_equal(expected, o.lines(0))
  end

  test "two attrs" do
    o = FactoryBot.create(:object_node)
    FactoryBot.create(:object_attribute, parent: o, name: "name")

    p = FactoryBot.create(:primitive_node, kind: "number")
    FactoryBot.create(:object_attribute, parent: o, name: "age", value: p)

    expected = [ "{", "  name: string", "  age: number", "}" ]
    assert_equal(expected, o.lines(0))
  end

  test "nested object" do
    o = FactoryBot.create(:object_node)
    FactoryBot.create(:object_attribute, parent: o, name: "name")

    nested_o = FactoryBot.create(:object_node)
    FactoryBot.create(:object_attribute, parent: o, name: "child", value: nested_o)
    FactoryBot.create(:object_attribute, parent: nested_o, name: "nested_name",)

    expected = [ "{", "  name: string", "  child: {", "    nested_name: string", "  }",  "}" ]
    assert_equal(expected, o.lines(0))
  end
end
