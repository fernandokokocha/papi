require "rails_helper"

describe OpenAPI::ImportSchema do
  def value(schema, entities: {}, schemas: {})
    OpenAPI::ImportSchema.new(schema, entities, schemas).call.serialize
  end

  it "maps every JSON Schema type onto a primitive" do
    expect(value({ "type" => "string" })).to eq("string")
    expect(value({ "type" => "number" })).to eq("number")
    expect(value({ "type" => "boolean" })).to eq("boolean")
    expect(value({ "type" => "null" })).to eq("null")
  end

  it "narrows an integer to a number" do
    expect(value({ "type" => "integer", "format" => "int64" })).to eq("number")
  end

  it "falls back to a string for a type papi cannot express" do
    expect(value({ "type" => "file" })).to eq("string")
    expect(value({})).to eq("string")
  end

  it "takes an enum as the type of its values" do
    expect(value({ "enum" => [ "open", "merged" ] })).to eq("string")
    expect(value({ "enum" => [ 1, 2 ] })).to eq("number")
    expect(value({ "type" => "string", "enum" => [ "open" ] })).to eq("string")
  end

  it "marks the attributes missing from required as optional" do
    schema = {
      "type" => "object",
      "properties" => { "id" => { "type" => "integer" }, "name" => { "type" => "string" } },
      "required" => [ "id" ]
    }

    expect(value(schema)).to eq("{id:number,name?:string}")
  end

  it "treats properties without a declared type as an object" do
    expect(value({ "properties" => { "id" => { "type" => "string" } } })).to eq("{id?:string}")
  end

  it "imports an object that declares no properties" do
    expect(value({ "type" => "object" })).to eq("{}")
  end

  it "maps items onto an array" do
    expect(value({ "type" => "array", "items" => { "type" => "string" } })).to eq("[string]")
  end

  it "types an array without items as an array of strings" do
    expect(value({ "type" => "array" })).to eq("[string]")
  end

  it "maps oneOf and anyOf onto a one-of" do
    expect(value({ "oneOf" => [ { "type" => "string" }, { "type" => "null" } ] })).to eq("(string|null)")
    expect(value({ "anyOf" => [ { "type" => "string" }, { "type" => "number" } ] })).to eq("(string|number)")
  end

  it "collapses a one-of of a single branch" do
    expect(value({ "oneOf" => [ { "type" => "string" } ] })).to eq("string")
  end

  it "drops the branches that repeat a named type" do
    schema = { "oneOf" => [ { "type" => "integer" }, { "type" => "number" }, { "type" => "string" } ] }

    expect(value(schema)).to eq("(number|string)")
  end

  it "keeps two object branches, which share no name to collide" do
    schema = {
      "oneOf" => [
        { "type" => "object", "properties" => { "a" => { "type" => "string" } }, "required" => [ "a" ] },
        { "type" => "object", "properties" => { "b" => { "type" => "string" } }, "required" => [ "b" ] }
      ]
    }

    expect(value(schema)).to eq("({a:string}|{b:string})")
  end

  it "lifts a nested one-of into its parent, since a branch may not be a one-of" do
    schema = {
      "oneOf" => [
        { "oneOf" => [ { "type" => "string" }, { "type" => "number" } ] },
        { "type" => "boolean" }
      ]
    }

    expect(value(schema)).to eq("(string|number|boolean)")
  end

  it "reads the 3.1 type union" do
    expect(value({ "type" => [ "string", "null" ] })).to eq("(string|null)")
  end

  it "reads a 3.1 union that carries the object's properties" do
    schema = {
      "type" => [ "object", "null" ],
      "properties" => { "id" => { "type" => "string" } },
      "required" => [ "id" ]
    }

    expect(value(schema)).to eq("({id:string}|null)")
  end

  it "reads the 3.0 nullable as a null branch" do
    expect(value({ "type" => "string", "nullable" => true })).to eq("(string|null)")
    expect(value({ "type" => "array", "items" => { "type" => "number" }, "nullable" => true })).to eq("([number]|null)")
  end

  it "adds the null branch to a nullable one-of rather than nesting it" do
    schema = { "oneOf" => [ { "type" => "string" }, { "type" => "number" } ], "nullable" => true }

    expect(value(schema)).to eq("(string|number|null)")
  end

  it "leaves a one-of that is already nullable alone" do
    schema = { "oneOf" => [ { "type" => "string" }, { "type" => "null" } ], "nullable" => true }

    expect(value(schema)).to eq("(string|null)")
  end

  it "resolves a components ref to an entity reference" do
    entities = { "Customer" => FakeEntity.new("Customer", "{id:number}") }

    expect(value({ "$ref" => "#/components/schemas/Customer" }, entities: entities)).to eq("Customer")
  end

  it "refuses a ref it cannot resolve" do
    expect { value({ "$ref" => "./common.yaml#/Customer" }) }.to raise_error(OpenAPI::Invalid, /Cannot resolve/)
    expect { value({ "$ref" => "#/components/schemas/Missing" }) }.to raise_error(OpenAPI::Invalid, /Cannot resolve/)
  end

  it "merges the objects an allOf composes" do
    schema = {
      "allOf" => [
        { "type" => "object", "properties" => { "id" => { "type" => "integer" } }, "required" => [ "id" ] },
        { "type" => "object", "properties" => { "name" => { "type" => "string" } } }
      ]
    }

    expect(value(schema)).to eq("{id:number,name?:string}")
  end

  it "inlines the schema an allOf branch refers to, losing the reference" do
    schemas = {
      "Base" => { "type" => "object", "properties" => { "id" => { "type" => "string" } }, "required" => [ "id" ] }
    }
    schema = {
      "allOf" => [
        { "$ref" => "#/components/schemas/Base" },
        { "type" => "object", "properties" => { "name" => { "type" => "string" } }, "required" => [ "name" ] }
      ]
    }

    expect(value(schema, schemas: schemas)).to eq("{id:string,name:string}")
  end

  it "ignores an allOf branch that is not an object" do
    schema = {
      "allOf" => [
        { "type" => "object", "properties" => { "id" => { "type" => "string" } }, "required" => [ "id" ] },
        { "type" => "string" }
      ]
    }

    expect(value(schema)).to eq("{id:string}")
  end

  it "nests to any depth" do
    schema = {
      "type" => "object",
      "properties" => {
        "orders" => {
          "type" => "array",
          "items" => {
            "type" => "object",
            "properties" => {
              "items" => { "type" => "array", "items" => { "oneOf" => [ { "type" => "string" }, { "type" => "integer" } ] } }
            },
            "required" => [ "items" ]
          }
        }
      },
      "required" => [ "orders" ]
    }

    expect(value(schema)).to eq("{orders:[{items:[(string|number)]}]}")
  end

  it "builds a tree the parser reads back unchanged" do
    schema = {
      "type" => "object",
      "properties" => { "tags" => { "type" => "array", "items" => { "type" => "string" } } },
      "required" => [ "tags" ]
    }
    node = OpenAPI::ImportSchema.new(schema).call

    expect(JSONSchemaParser.new.parse_value(node.serialize)).to eq(node)
  end
end
