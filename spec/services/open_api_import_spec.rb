require "rails_helper"

describe OpenAPI::Import do
  let(:group) { FactoryBot.create(:group) }
  let(:user) { FactoryBot.create(:user, group: group) }
  let(:project) { FactoryBot.create(:project, name: "Shop", group: group) }

  def import(paths: {}, components: nil, openapi: "3.1.0")
    document = { "openapi" => openapi, "info" => { "title" => "Shop", "version" => "1" }, "paths" => paths }
    document["components"] = components if components

    service = OpenAPI::Import.new(project, document.to_json, author: user)
    service.call
    service
  end

  def version(service)
    service.candidate.latest_version
  end

  def endpoint(service, name)
    version(service).endpoints.find { |endpoint| endpoint.name == name }
  end

  it "opens a candidate holding one version" do
    service = import(paths: { "/users" => { "get" => { "responses" => {} } } })

    expect(service.candidate.name).to eq("rc1")
    expect(service.candidate.author).to eq(user)
    expect(service.candidate).to be_open
    expect(version(service).name).to eq("rc1-v1")
    expect(version(service).project).to be_nil
  end

  it "numbers the candidate after the last one and bases it on the latest version" do
    merged = FactoryBot.create(:candidate, project: project, name: "rc1", order: 1)
    released = FactoryBot.create(:version, candidate: merged, project: project, name: "v1", order: 1)
    merged.merge!

    service = import(paths: { "/users" => { "get" => {} } })

    expect(service.candidate.name).to eq("rc2")
    expect(service.candidate.base_version).to eq(released)
  end

  it "refuses to import while a candidate is open" do
    FactoryBot.create(:candidate, project: project, name: "rc1", order: 1)

    expect { import(paths: {}) }.to raise_error(OpenAPI::Invalid, /already has an open candidate/)
  end

  it "refuses a document that is not OpenAPI 3" do
    expect { import(openapi: "2.0") }.to raise_error(OpenAPI::Invalid, /not an OpenAPI 3 document/)
    expect { OpenAPI::Import.new(project, "just a note").call }.to raise_error(OpenAPI::Invalid, /not an OpenAPI 3/)
  end

  it "refuses a file that parses as neither JSON nor YAML" do
    expect { OpenAPI::Import.new(project, "{ nope: [").call }.to raise_error(OpenAPI::Invalid, /neither JSON nor YAML/)
  end

  it "reads a YAML document as readily as a JSON one" do
    yaml = <<~YAML
      openapi: 3.1.0
      info:
        title: Shop
        version: "1"
      paths:
        /users:
          get:
            responses:
              "200":
                description: The users
    YAML
    service = OpenAPI::Import.new(project, yaml, author: user)
    service.call

    expect(endpoint(service, "GET /users").responses.first.note).to eq("The users")
  end

  it "writes an OpenAPI path template the way Papi writes a path" do
    service = import(paths: { "/users/{id}/orders/{order_id}" => { "get" => {} } })

    expect(version(service).endpoints.map(&:path)).to eq([ "/users/:id/orders/:order_id" ])
  end

  it "renames a param the DSL cannot spell" do
    service = import(paths: { "/users/{user-id}" => { "get" => {} } })

    expect(version(service).endpoints.map(&:path)).to eq([ "/users/:user_id" ])
  end

  it "skips a path segment holding more than a single param" do
    service = import(paths: {
      "/files/{name}.{ext}" => { "get" => {} },
      "/files/{name}" => { "get" => {} }
    })

    expect(version(service).endpoints.map(&:path)).to eq([ "/files/:name" ])
  end

  it "imports every verb Papi knows and skips the rest" do
    operations = OpenAPI::Import::VERBS.keys.index_with { {} }.merge("head" => {}, "options" => {}, "trace" => {})
    service = import(paths: { "/users" => operations })

    expect(version(service).endpoints.map(&:verb)).to match_array(%w[GET POST PUT PATCH DELETE])
  end

  it "joins the summary and the description into one note" do
    service = import(paths: { "/users" => {
      "get" => { "summary" => "Lists users", "description" => "Paginated" },
      "post" => { "description" => "Creates one" },
      "put" => {}
    } })

    expect(endpoint(service, "GET /users").note).to eq("Lists users — Paginated")
    expect(endpoint(service, "POST /users").note).to eq("Creates one")
    expect(endpoint(service, "PUT /users").note).to eq("")
  end

  it "takes the JSON request body as the input" do
    service = import(paths: { "/users" => { "post" => {
      "requestBody" => { "content" => { "application/json" => { "schema" => {
        "type" => "object", "properties" => { "email" => { "type" => "string" } }, "required" => [ "email" ]
      } } } }
    } } })

    expect(endpoint(service, "POST /users").input).to eq("{email:string}")
  end

  it "matches a JSON media type that carries parameters" do
    service = import(paths: { "/users" => { "post" => {
      "requestBody" => { "content" => { "application/json; charset=utf-8" => { "schema" => { "type" => "string" } } } }
    } } })

    expect(endpoint(service, "POST /users").input).to eq("string")
  end

  it "declares no input for a body Papi cannot read" do
    service = import(paths: { "/uploads" => { "post" => {
      "requestBody" => { "content" => { "multipart/form-data" => { "schema" => { "type" => "string" } } } }
    } } })

    expect(endpoint(service, "POST /uploads").input).to eq("")
  end

  it "keeps the path and query params and drops the header ones" do
    service = import(paths: { "/users/{id}" => { "get" => { "parameters" => [
      { "name" => "id", "in" => "path", "required" => true, "schema" => { "type" => "integer" } },
      { "name" => "page", "in" => "query", "required" => true, "schema" => { "type" => "number" } },
      { "name" => "verbose", "in" => "query", "schema" => { "type" => "boolean" } },
      { "name" => "X-Request-Id", "in" => "header", "schema" => { "type" => "string" } }
    ] } } })
    imported = endpoint(service, "GET /users/:id")

    expect(imported.path_params.map { |param| [ param.name, param.kind ] }).to eq([ [ "id", "number" ] ])
    expect(imported.query_params.map { |param| [ param.name, param.kind, param.required ] }).to eq([
      [ "page", "number", true ],
      [ "verbose", "boolean", false ]
    ])
  end

  it "adds the params a path item shares, letting the operation's own win" do
    service = import(paths: { "/users/{id}" => {
      "parameters" => [
        { "name" => "id", "in" => "path", "schema" => { "type" => "string" } },
        { "name" => "page", "in" => "query", "schema" => { "type" => "number" } }
      ],
      "get" => { "parameters" => [ { "name" => "id", "in" => "path", "schema" => { "type" => "integer" } } ] }
    } })
    imported = endpoint(service, "GET /users/:id")

    expect(imported.path_params.map { |param| [ param.name, param.kind ] }).to eq([ [ "id", "number" ] ])
    expect(imported.query_params.map(&:name)).to eq([ "page" ])
  end

  it "keys responses by code and takes the description as the note" do
    service = import(paths: { "/users" => { "get" => { "responses" => {
      "200" => { "description" => "The users", "content" => { "application/json" => { "schema" => { "type" => "array", "items" => { "type" => "string" } } } } },
      "404" => { "description" => "Missing" }
    } } } })
    responses = endpoint(service, "GET /users").responses.sort_by(&:code)

    expect(responses.map { |response| [ response.code, response.note, response.output ] }).to eq([
      [ "200", "The users", "[string]" ],
      [ "404", "Missing", "" ]
    ])
  end

  it "skips a response Papi cannot key by status code" do
    service = import(paths: { "/users" => { "get" => { "responses" => {
      "200" => { "description" => "OK" },
      "2XX" => { "description" => "Fine" },
      "default" => { "description" => "Anything else" }
    } } } })

    expect(endpoint(service, "GET /users").responses.map(&:code)).to eq([ "200" ])
  end

  describe "an operation with no response Papi can key" do
    it "keeps the default under a code Papi can hold, so the endpoint is usable" do
      service = import(paths: { "/users" => { "delete" => { "responses" => {
        "default" => { "description" => "Whatever happened", "content" => { "application/json" => { "schema" => { "type" => "string" } } } }
      } } } })
      response = endpoint(service, "DELETE /users").responses.sole

      expect(response.code).to eq("200")
      expect(response.note).to eq("Whatever happened")
      expect(response.output).to eq("string")
    end

    it "falls back to a wildcard when there is no default" do
      service = import(paths: { "/users" => { "get" => { "responses" => { "2XX" => { "description" => "Fine" } } } } })

      expect(endpoint(service, "GET /users").responses.map { |r| [ r.code, r.note ] }).to eq([ [ "200", "Fine" ] ])
    end

    it "gives an operation declaring no responses at all a bare one" do
      service = import(paths: { "/users" => { "get" => {} } })

      expect(endpoint(service, "GET /users").responses.map { |r| [ r.code, r.note, r.output ] }).to eq([ [ "200", "", "" ] ])
    end
  end

  describe "a body Papi has no type for" do
    def map_schema
      { "type" => "object", "additionalProperties" => { "type" => "integer" } }
    end

    it "declares nothing rather than an empty object" do
      service = import(paths: { "/inventory" => { "get" => { "responses" => {
        "200" => { "description" => "By status", "content" => { "application/json" => { "schema" => map_schema } } }
      } } } })

      expect(endpoint(service, "GET /inventory").responses.sole.output).to eq("")
    end

    it "keeps the empty object where nothing cannot be spelled" do
      components = { "schemas" => { "Inventory" => map_schema } }
      paths = { "/inventory" => { "get" => { "responses" => {
        "200" => { "description" => "By status", "content" => { "application/json" => { "schema" => {
          "type" => "object", "properties" => { "counts" => map_schema }, "required" => [ "counts" ]
        } } } }
      } } } }
      service = import(paths: paths, components: components)

      expect(version(service).entities.sole.root).to eq("{}")
      expect(endpoint(service, "GET /inventory").responses.sole.output).to eq("{counts:{}}")
    end
  end

  it "imports components as entities that endpoints refer to" do
    components = { "schemas" => {
      "Customer" => { "type" => "object", "properties" => { "id" => { "type" => "integer" }, "address" => { "$ref" => "#/components/schemas/Address" } }, "required" => [ "id" ] },
      "Address" => { "type" => "object", "properties" => { "city" => { "type" => "string" } }, "required" => [ "city" ] }
    } }
    paths = { "/customers" => { "get" => { "responses" => {
      "200" => { "description" => "ok", "content" => { "application/json" => { "schema" => { "type" => "array", "items" => { "$ref" => "#/components/schemas/Customer" } } } } }
    } } } }
    service = import(paths: paths, components: components)

    expect(version(service).entities.map { |entity| [ entity.name, entity.root ] }).to eq([
      [ "Address", "{city:string}" ],
      [ "Customer", "{id:number,address?:Address}" ]
    ])
    expect(endpoint(service, "GET /customers").responses.first.output).to eq("[Customer]")
  end

  it "renames a component the parser would read as a primitive" do
    components = { "schemas" => { "numberOfItems" => { "type" => "integer" } } }
    paths = { "/counts" => { "get" => { "responses" => {
      "200" => { "description" => "ok", "content" => { "application/json" => { "schema" => { "$ref" => "#/components/schemas/numberOfItems" } } } }
    } } } }
    service = import(paths: paths, components: components)

    expect(version(service).entities.map(&:name)).to eq([ "NumberOfItems" ])
    expect(endpoint(service, "GET /counts").responses.first.output).to eq("NumberOfItems")
  end

  it "refuses a document whose entities refer to each other in a circle" do
    components = { "schemas" => {
      "Node" => { "type" => "object", "properties" => { "children" => { "type" => "array", "items" => { "$ref" => "#/components/schemas/Node" } } } }
    } }

    expect { import(components: components) }.to raise_error(OpenAPI::Invalid, /circle/)
  end

  it "refuses a document whose paths collide once params are erased" do
    paths = { "/users/{id}" => { "get" => {} }, "/users/{user_id}" => { "get" => {} } }

    expect { import(paths: paths) }.to raise_error(OpenAPI::Invalid, /collide/)
  end

  describe "a document that changes nothing" do
    let(:paths) do
      { "/users" => { "get" => { "responses" => {
        "200" => { "description" => "The users", "content" => { "application/json" => { "schema" => {
          "type" => "object",
          "properties" => { "id" => { "type" => "string" }, "name" => { "type" => "string" } },
          "required" => [ "id", "name" ]
        } } } }
      } } } }
    end

    def release(output)
      merged = FactoryBot.create(:candidate, project: project, name: "rc1", order: 1)
      released = FactoryBot.create(:version, candidate: merged, project: project, name: "v1", order: 1)
      endpoint = FactoryBot.create(:endpoint, version: released, path: "/users", http_verb: "verb_get", note: "")
      FactoryBot.create(:response, endpoint: endpoint, code: "200", note: "The users", output: output)
      merged.merge!
    end

    it "is refused, because a candidate that changes nothing has nothing to review" do
      release("{id:string,name:string}")

      expect { import(paths: paths) }.to raise_error(OpenAPI::Invalid, /nothing to review/)
    end

    it "is refused even when it declares the same object in another order" do
      release("{name:string,id:string}")

      expect { import(paths: paths) }.to raise_error(OpenAPI::Invalid, /nothing to review/)
    end

    it "leaves no candidate behind" do
      release("{id:string,name:string}")

      expect { import(paths: paths) rescue nil }.not_to change(Candidate, :count)
    end

    it "is accepted once a single response note differs" do
      release("{id:string,name:string}")
      changed = paths.deep_dup
      changed["/users"]["get"]["responses"]["200"]["description"] = "Every user"

      expect { import(paths: changed) }.to change(Candidate, :count).by(1)
    end

    it "is refused when an empty document meets an empty project" do
      expect { import(paths: {}) }.to raise_error(OpenAPI::Invalid, /nothing to review/)
    end
  end

  it "leaves no candidate behind when the import fails" do
    paths = { "/users/{id}" => { "get" => {} }, "/users/{user_id}" => { "get" => {} } }

    expect { import(paths: paths) rescue nil }.not_to change(Candidate, :count)
  end
end
