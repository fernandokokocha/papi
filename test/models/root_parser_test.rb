require "test_helper"

class RootParserTest < ActiveSupport::TestCase
  test "parse {}" do
    actual = RootParser.new.parse_object("{}")
    expected = ObjectNode.new
    assert_equal expected, actual
  end

  test "parse { a: string }" do
    actual = RootParser.new.parse_object("{ a: string }")
    actual.save
    expected = FactoryBot.create(:object_node, object_attributes: [
      FactoryBot.create(:object_attribute, order: 0, name: "a")
    ])

    assert_equal expected, actual
  end

  test "parse { a: number }" do
    actual = RootParser.new.parse_object("{ a: number }")
    actual.save
    expected = FactoryBot.create(:object_node, object_attributes: [
      FactoryBot.create(:object_attribute, order: 0, name: "a", value:
        FactoryBot.create(:primitive_node, kind: "number"))
    ])

    assert_equal expected, actual
  end

  test "parse { a: string, b: number }" do
    actual = RootParser.new.parse_object("{ a: string, b: number }")
    actual.save
    expected = FactoryBot.create(:object_node, object_attributes: [
      FactoryBot.create(:object_attribute, order: 0, name: "a"),
      FactoryBot.create(:object_attribute, order: 1, name: "b", value:
        FactoryBot.create(:primitive_node, kind: "number"))
    ])

    assert_equal expected, actual
  end

  test "parse { a: { b: string } }" do
    actual = RootParser.new.parse_object("{ a: { b: string } }")
    actual.save
    expected = FactoryBot.create(:object_node, object_attributes: [
      FactoryBot.create(:object_attribute, order: 0, name: "a", value:
        FactoryBot.create(:object_node, object_attributes: [
          FactoryBot.create(:object_attribute, order: 0, name: "b")
        ]))
    ])

    assert_equal expected, actual
  end

  test "parse { a: { b: string, c: number } }" do
    actual = RootParser.new.parse_object("{ a: { b: string, c: number } }")
    actual.save
    expected = FactoryBot.create(:object_node, object_attributes: [
      FactoryBot.create(:object_attribute, order: 0, name: "a", value:
        FactoryBot.create(:object_node, object_attributes: [
          FactoryBot.create(:object_attribute, order: 0, name: "b"),
          FactoryBot.create(:object_attribute, order: 1, name: "c", value:
            FactoryBot.create(:primitive_node, kind: "number")
          )
        ]))
    ])

    assert_equal expected, actual
  end

  test "parse real life problem" do
    actual = RootParser.new.parse_object("{name:string,child:{first_name:string,last_name:string,third_name:number},elo:string}")
    actual.save
    expected = FactoryBot.create(:object_node, object_attributes: [
      FactoryBot.create(:object_attribute, order: 0, name: "name"),
      FactoryBot.create(:object_attribute, order: 1, name: "child", value:
        FactoryBot.create(:object_node, object_attributes: [
          FactoryBot.create(:object_attribute, order: 0, name: "first_name"),
          FactoryBot.create(:object_attribute, order: 1, name: "last_name"),
          FactoryBot.create(:object_attribute, order: 2, name: "third_name", value:
            FactoryBot.create(:primitive_node, kind: "number")
          )
        ])),
      FactoryBot.create(:object_attribute, order: 2, name: "elo")
    ])

    assert_equal expected, actual
  end

  test "parse three levels of nesting" do
    actual = RootParser.new.parse_object("{name:string,child:{first_name:string,last_name:string,obj:{new:string}}}")
    actual.save
    expected = FactoryBot.create(:object_node, object_attributes: [
      FactoryBot.create(:object_attribute, order: 0, name: "name"),
      FactoryBot.create(:object_attribute, order: 1, name: "child", value:
        FactoryBot.create(:object_node, object_attributes: [
          FactoryBot.create(:object_attribute, order: 0, name: "first_name"),
          FactoryBot.create(:object_attribute, order: 1, name: "last_name"),
          FactoryBot.create(:object_attribute, order: 2, name: "obj", value:
            FactoryBot.create(:object_node, object_attributes: [
              FactoryBot.create(:object_attribute, order: 0, name: "new")
            ])
          )
        ]))
    ])

    assert_equal expected, actual
  end
end
