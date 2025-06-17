require "rails_helper"

describe JSONSchemaParser, type: :model do
  subject(:parser) { JSONSchemaParser.new }

  describe "#parse_value" do
    it "parse empty string" do
      actual = parser.parse_value("")
      expected = NothingNode.new
      expect(actual).to eq(expected)
    end

    it "parse {}" do
      actual = parser.parse_value("{}")
      expected = ObjectNode.new
      expect(actual).to eq(expected)
    end

    it "parse { a: string }" do
      actual = parser.parse_value("{ a: string }")
      actual.save
      expected = FactoryBot.create(:object_node, object_attributes: [
        FactoryBot.create(:object_attribute, order: 0, name: "a")
      ])

      expect(actual).to eq(expected)
    end

    it "parse { a: number }" do
      actual = parser.parse_value("{ a: number }")
      actual.save
      expected = FactoryBot.create(:object_node, object_attributes: [
        FactoryBot.create(:object_attribute, order: 0, name: "a", value:
          FactoryBot.create(:primitive_node, kind: "number"))
      ])

      expect(actual).to eq(expected)
    end

    it "parse { a: string, b: number }" do
      actual = parser.parse_value("{ a: string, b: number }")
      actual.save
      expected = FactoryBot.create(:object_node, object_attributes: [
        FactoryBot.create(:object_attribute, order: 0, name: "a"),
        FactoryBot.create(:object_attribute, order: 1, name: "b", value:
          FactoryBot.create(:primitive_node, kind: "number"))
      ])

      expect(actual).to eq(expected)
    end

    it "parse { a: { b: string } }" do
      actual = parser.parse_value("{ a: { b: string } }")
      actual.save
      expected = FactoryBot.create(:object_node, object_attributes: [
        FactoryBot.create(:object_attribute, order: 0, name: "a", value:
          FactoryBot.create(:object_node, object_attributes: [
            FactoryBot.create(:object_attribute, order: 0, name: "b")
          ]))
      ])

      expect(actual).to eq(expected)
    end

    it "parse { a: { b: string, c: number } }" do
      actual = parser.parse_value("{ a: { b: string, c: number } }")
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

      expect(actual).to eq(expected)
    end

    it "parse real life problem" do
      actual = parser.parse_value("{name:string,child:{first_name:string,last_name:string,third_name:number},elo:string}")
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

      expect(actual).to eq(expected)
    end

    it "parse three levels of nesting" do
      actual = parser.parse_value("{name:string,child:{first_name:string,last_name:string,obj:{new:string}}}")
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

      expect(actual).to eq(expected)
    end

    it "parse array of strings" do
      actual = parser.parse_value("[string]")
      actual.save
      expected = FactoryBot.create(:array_node, value:
        FactoryBot.create(:primitive_node)
      )

      expect(actual).to eq(expected)
    end

    it "parse array of objects" do
      actual = parser.parse_value("[{ a: string }]")
      actual.save
      expected = FactoryBot.create(:array_node, value:
        FactoryBot.create(:object_node, object_attributes: [
          FactoryBot.create(:object_attribute, order: 0, name: "a")
        ]))

      expect(actual).to eq(expected)
    end

    it "parse primitive" do
      actual = parser.parse_value("boolean")
      actual.save
      expected = FactoryBot.create(:primitive_node, kind: "boolean")

      expect(actual).to eq(expected)
    end

    it "complex example" do
      actual = parser.parse_value("{name:string,ref:string,is_pies:boolean,obj1:{first_name:string,last_name:string},array1:[{id:number,is_confirmed:boolean}],array2:[number]}")
      actual.save

      expected = FactoryBot.create(:object_node, object_attributes: [
        FactoryBot.create(:object_attribute, order: 0, name: "name"),
        FactoryBot.create(:object_attribute, order: 1, name: "ref"),
        FactoryBot.create(:object_attribute, order: 2, name: "is_pies", value:
          FactoryBot.create(:primitive_node, kind: "boolean")
        ),
        FactoryBot.create(:object_attribute, order: 3, name: "obj1", value:
          FactoryBot.create(:object_node, object_attributes: [
            FactoryBot.create(:object_attribute, order: 0, name: "first_name"),
            FactoryBot.create(:object_attribute, order: 1, name: "last_name")
          ]
          )),
        FactoryBot.create(:object_attribute, order: 4, name: "array1", value:
          FactoryBot.create(:array_node, value:
            FactoryBot.create(:object_node, object_attributes: [
              FactoryBot.create(:object_attribute, order: 0, name: "id", value:
                FactoryBot.create(:primitive_node, kind: "number")
              ),
              FactoryBot.create(:object_attribute, order: 1, name: "is_confirmed", value:
                FactoryBot.create(:primitive_node, kind: "boolean")
              )
            ]
            ))),
        FactoryBot.create(:object_attribute, order: 5, name: "array2", value:
          FactoryBot.create(:array_node, value:
            FactoryBot.create(:primitive_node, kind: "number")
          ))
      ])

      expect(actual).to eq(expected)
    end
  end
end
