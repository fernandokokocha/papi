require "rails_helper"

describe OpenAPI::ExportSchema do
  def schema(value, entities: [])
    OpenAPI::ExportSchema.new(JSONSchemaParser.new(entities).parse_value(value)).call
  end

  it "maps every primitive onto its JSON Schema type" do
    expect(schema("string")).to eq({ "type" => "string" })
    expect(schema("number")).to eq({ "type" => "number" })
    expect(schema("boolean")).to eq({ "type" => "boolean" })
    expect(schema("null")).to eq({ "type" => "null" })
  end

  it "lists an object's mandatory attributes as required" do
    expect(schema("{id:number,name?:string}")).to eq({
      "type" => "object",
      "properties" => {
        "id" => { "type" => "number" },
        "name" => { "type" => "string" }
      },
      "required" => [ "id" ]
    })
  end

  it "omits required when every attribute is optional" do
    expect(schema("{name?:string}")).to eq({
      "type" => "object",
      "properties" => { "name" => { "type" => "string" } }
    })
  end

  it "maps an array onto items" do
    expect(schema("[string]")).to eq({ "type" => "array", "items" => { "type" => "string" } })
  end

  it "maps a one-of onto oneOf" do
    expect(schema("(string|null)")).to eq({
      "oneOf" => [ { "type" => "string" }, { "type" => "null" } ]
    })
  end

  it "maps an entity reference onto a components ref" do
    customer = FakeEntity.new("Customer", "{id:number}")

    expect(schema("Customer", entities: [ customer ])).to eq({ "$ref" => "#/components/schemas/Customer" })
  end

  it "refers to a nested entity rather than expanding it" do
    address = FakeEntity.new("Address", "{city:string}")
    customer = FakeEntity.new("Customer", "{address:Address}")

    expect(schema("[Customer]", entities: [ address, customer ])).to eq({
      "type" => "array",
      "items" => { "$ref" => "#/components/schemas/Customer" }
    })
  end

  it "nests to any depth" do
    expect(schema("{orders:[{items:[(string|number)]}]}")).to eq({
      "type" => "object",
      "properties" => {
        "orders" => {
          "type" => "array",
          "items" => {
            "type" => "object",
            "properties" => {
              "items" => {
                "type" => "array",
                "items" => { "oneOf" => [ { "type" => "string" }, { "type" => "number" } ] }
              }
            },
            "required" => [ "items" ]
          }
        }
      },
      "required" => [ "orders" ]
    })
  end

  it "refuses to express nothing" do
    expect { OpenAPI::ExportSchema.new(Node::Nothing.new).call }.to raise_error(/no JSON Schema equivalent/)
  end
end
