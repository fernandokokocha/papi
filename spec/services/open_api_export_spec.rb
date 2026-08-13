require "rails_helper"

describe OpenAPI::Export do
  let(:project) { FactoryBot.create(:project, name: "Shop") }
  let(:version) { FactoryBot.create(:version, project: project, name: "v2") }

  def document
    OpenAPI::Export.new(version.reload).call
  end

  it "titles the document after the project and versions it after the version" do
    expect(document["openapi"]).to eq("3.1.0")
    expect(document["info"]).to eq({ "title" => "Shop", "version" => "v2" })
  end

  it "templates path params the way OpenAPI writes them" do
    FactoryBot.create(:endpoint, version: version, path: "/users/:id/orders/:order_id")

    expect(document["paths"].keys).to eq([ "/users/{id}/orders/{order_id}" ])
  end

  it "gathers the verbs of one path into a single path item" do
    FactoryBot.create(:endpoint, version: version, path: "/users", http_verb: "verb_get")
    FactoryBot.create(:endpoint, version: version, path: "/users", http_verb: "verb_post")

    expect(document["paths"]["/users"].keys).to match_array([ "get", "post" ])
  end

  it "declares a path param as required and a query param as declared" do
    endpoint = FactoryBot.create(:endpoint, version: version, path: "/users/:id")
    FactoryBot.create(:endpoint_param, endpoint: endpoint, name: "id", kind: "number", location: "path")
    FactoryBot.create(:endpoint_param, endpoint: endpoint, name: "verbose", kind: "boolean", location: "query", required: false)
    FactoryBot.create(:endpoint_param, endpoint: endpoint, name: "page", kind: "number", location: "query", required: true)

    expect(document["paths"]["/users/{id}"]["get"]["parameters"]).to eq([
      { "name" => "id", "in" => "path", "required" => true, "schema" => { "type" => "number" } },
      { "name" => "page", "in" => "query", "required" => true, "schema" => { "type" => "number" } },
      { "name" => "verbose", "in" => "query", "required" => false, "schema" => { "type" => "boolean" } }
    ])
  end

  it "types an undeclared path param as a string" do
    FactoryBot.create(:endpoint, version: version, path: "/users/:id")

    expect(document["paths"]["/users/{id}"]["get"]["parameters"]).to eq([
      { "name" => "id", "in" => "path", "required" => true, "schema" => { "type" => "string" } }
    ])
  end

  it "omits parameters from an endpoint that takes none" do
    FactoryBot.create(:endpoint, version: version, path: "/users")

    expect(document["paths"]["/users"]["get"]).not_to have_key("parameters")
  end

  it "carries the note across as a summary" do
    FactoryBot.create(:endpoint, version: version, path: "/users", note: "Lists every user")

    expect(document["paths"]["/users"]["get"]["summary"]).to eq("Lists every user")
  end

  it "omits the summary of an endpoint without a note" do
    FactoryBot.create(:endpoint, version: version, path: "/users", note: "")

    expect(document["paths"]["/users"]["get"]).not_to have_key("summary")
  end

  it "sends the input as a required JSON request body" do
    FactoryBot.create(:endpoint, version: version, path: "/users", http_verb: "verb_post", input: "{name:string}")

    expect(document["paths"]["/users"]["post"]["requestBody"]).to eq({
      "required" => true,
      "content" => {
        "application/json" => {
          "schema" => {
            "type" => "object",
            "properties" => { "name" => { "type" => "string" } },
            "required" => [ "name" ]
          }
        }
      }
    })
  end

  it "omits the request body of an endpoint that declares no input" do
    FactoryBot.create(:endpoint, version: version, path: "/users", input: "")

    expect(document["paths"]["/users"]["get"]).not_to have_key("requestBody")
  end

  it "keys responses by code and describes them with their note" do
    endpoint = FactoryBot.create(:endpoint, version: version, path: "/users")
    FactoryBot.create(:response, endpoint: endpoint, code: "200", note: "The users", output: "[string]")

    expect(document["paths"]["/users"]["get"]["responses"]).to eq({
      "200" => {
        "description" => "The users",
        "content" => {
          "application/json" => { "schema" => { "type" => "array", "items" => { "type" => "string" } } }
        }
      }
    })
  end

  it "falls back to the status name when a response has no note" do
    endpoint = FactoryBot.create(:endpoint, version: version, path: "/users")
    FactoryBot.create(:response, endpoint: endpoint, code: "404", note: "", output: "string")

    expect(document["paths"]["/users"]["get"]["responses"]["404"]["description"]).to eq("Not Found")
  end

  it "gives a response with no output no content at all" do
    endpoint = FactoryBot.create(:endpoint, version: version, path: "/users", http_verb: "verb_delete")
    FactoryBot.create(:response, endpoint: endpoint, code: "204", note: "", output: "")

    expect(document["paths"]["/users"]["delete"]["responses"]["204"]).to eq({ "description" => "No Content" })
  end

  it "publishes entities as components and refers to them" do
    FactoryBot.create(:entity, version: version, name: "Customer", root: "{id:number,address?:Address}")
    FactoryBot.create(:entity, version: version, name: "Address", root: "{city:string}")
    endpoint = FactoryBot.create(:endpoint, version: version, path: "/customers")
    FactoryBot.create(:response, endpoint: endpoint, code: "200", note: "ok", output: "[Customer]")

    expect(document["components"]["schemas"]).to eq({
      "Address" => {
        "type" => "object",
        "properties" => { "city" => { "type" => "string" } },
        "required" => [ "city" ]
      },
      "Customer" => {
        "type" => "object",
        "properties" => {
          "id" => { "type" => "number" },
          "address" => { "$ref" => "#/components/schemas/Address" }
        },
        "required" => [ "id" ]
      }
    })
    expect(document["paths"]["/customers"]["get"]["responses"]["200"]["content"]["application/json"]["schema"]).to eq({
      "type" => "array",
      "items" => { "$ref" => "#/components/schemas/Customer" }
    })
  end

  it "omits components from a version with no entities and no auth methods" do
    FactoryBot.create(:endpoint, version: version, path: "/users")

    expect(document).not_to have_key("components")
  end

  it "publishes auth methods as HTTP security schemes" do
    FactoryBot.create(:auth_method, version: version, name: "UserToken", kind: "bearer",
                                    note: "Token from POST /sessions")
    FactoryBot.create(:auth_method, version: version, name: "AdminBasic", kind: "basic")
    FactoryBot.create(:endpoint, version: version, path: "/users")

    expect(document["components"]["securitySchemes"]).to eq({
      "AdminBasic" => { "type" => "http", "scheme" => "basic" },
      "UserToken" => { "type" => "http", "scheme" => "bearer", "description" => "Token from POST /sessions" }
    })
  end

  it "names the endpoint's method as its security requirement" do
    FactoryBot.create(:auth_method, version: version, name: "UserToken", kind: "bearer")
    FactoryBot.create(:endpoint, version: version, path: "/users", auth: "UserToken")

    expect(document["paths"]["/users"]["get"]["security"]).to eq([ { "UserToken" => [] } ])
  end

  # No root-level security is exported, so an operation with no requirement of
  # its own already reads as public. An empty list would say the same thing twice.
  it "leaves an endpoint that declares no auth without a security key" do
    FactoryBot.create(:auth_method, version: version, name: "UserToken", kind: "bearer")
    FactoryBot.create(:endpoint, version: version, path: "/users", auth: "")

    expect(document["paths"]["/users"]["get"]).not_to have_key("security")
    expect(document).not_to have_key("security")
  end

  # A note's path is a property reference, so it exports with no resolving.
  it "hangs a schema note on the property it addresses" do
    entity = Entity.create!(version: version, name: "User", root: "{id:number,tags:[string]}")
    entity.schema_notes.create!(path: '["id"]', body: "Opaque; never parse it.")
    entity.schema_notes.create!(path: '["tags",null]', body: "Lowercased on write.")

    schema = document.dig("components", "schemas", "User")

    expect(schema.dig("properties", "id", "description")).to eq("Opaque; never parse it.")
    expect(schema.dig("properties", "tags", "items", "description")).to eq("Lowercased on write.")
  end

  it "describes a one-of branch and the whole body by path" do
    endpoint = FactoryBot.create(:endpoint, version: version, path: "/sessions",
                                            http_verb: "verb_post", input: "{name:(string|null)}")
    endpoint.schema_notes.create!(path: '[]', body: "Everything here is trimmed.")
    endpoint.schema_notes.create!(path: '["name",1]', body: "Null means the user never set one.")

    schema = document.dig("paths", "/sessions", "post", "requestBody", "content", "application/json", "schema")

    expect(schema["description"]).to eq("Everything here is trimmed.")
    expect(schema.dig("properties", "name", "oneOf", 1, "description")).to eq("Null means the user never set one.")
  end

  it "leaves a schema alone when its notable has no notes" do
    Entity.create!(version: version, name: "Error", root: "{code:number}")

    expect(document.dig("components", "schemas", "Error")).not_to have_key("description")
    expect(document.dig("components", "schemas", "Error", "properties", "code")).not_to have_key("description")
  end
end
