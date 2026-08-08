require "rails_helper"

describe "OpenAPI export requests", type: :request do
  let(:group) { FactoryBot.create :group, name: "Test group" }
  let(:user) { FactoryBot.create :user, email_address: "test@example.com", password: "password", group: group }
  let(:project) { FactoryBot.create :project, name: "Shop", group: group }

  let(:another_group) { FactoryBot.create :group, name: "Test group 2" }
  let(:another_user) { FactoryBot.create :user, email_address: "outsider@example.com", password: "password", group: another_group }

  let(:candidate) { FactoryBot.create(:candidate, project: project) }
  let(:version) { FactoryBot.create(:version, candidate: candidate, project: project, name: "v1") }

  def export
    get project_version_openapi_path(project_name: project.name, version_name: version.name)
    JSON.parse(response.body)
  end

  it "downloads the document as a named JSON file" do
    sign_in(user)
    get project_version_openapi_path(project_name: project.name, version_name: version.name)

    expect(response.status).to eq(200)
    expect(response.media_type).to eq("application/json")
    expect(response.headers["Content-Disposition"]).to include("Shop-v1.json")
  end

  it "does not accept users from another group" do
    sign_in(another_user)
    get project_version_openapi_path(project_name: project.name, version_name: version.name)

    expect(response.status).to eq(302)
    expect(flash[:alert]).to eq("You are not authorized to perform this action.")
  end

  it "exports a version that declares nothing at all" do
    sign_in(user)

    expect(export).to eq({
      "openapi" => "3.1.0",
      "info" => { "title" => "Shop", "version" => "v1" },
      "paths" => {}
    })
  end

  it "exports a version of two endpoints and an entity" do
    FactoryBot.create(:entity, version: version, name: "Customer", root: "{id:number,email?:string}")

    create = FactoryBot.create(:endpoint, version: version, path: "/customers", http_verb: "verb_post",
                                          note: "Register a customer", input: "{email:string}")
    FactoryBot.create(:response, endpoint: create, code: "201", note: "The new customer", output: "Customer")
    FactoryBot.create(:response, endpoint: create, code: "422", note: "The email was taken", output: "{errors:[string]}")

    show = FactoryBot.create(:endpoint, version: version, path: "/customers/:id", http_verb: "verb_get", note: "")
    FactoryBot.create(:endpoint_param, endpoint: show, name: "id", kind: "number", location: "path")
    FactoryBot.create(:endpoint_param, endpoint: show, name: "expand", kind: "boolean", location: "query", required: false)
    FactoryBot.create(:response, endpoint: show, code: "200", note: "", output: "Customer")

    sign_in(user)

    expect(export).to eq({
      "openapi" => "3.1.0",
      "info" => { "title" => "Shop", "version" => "v1" },
      "paths" => {
        "/customers" => {
          "post" => {
            "summary" => "Register a customer",
            "requestBody" => {
              "required" => true,
              "content" => {
                "application/json" => {
                  "schema" => {
                    "type" => "object",
                    "properties" => { "email" => { "type" => "string" } },
                    "required" => [ "email" ]
                  }
                }
              }
            },
            "responses" => {
              "201" => {
                "description" => "The new customer",
                "content" => {
                  "application/json" => { "schema" => { "$ref" => "#/components/schemas/Customer" } }
                }
              },
              "422" => {
                "description" => "The email was taken",
                "content" => {
                  "application/json" => {
                    "schema" => {
                      "type" => "object",
                      "properties" => { "errors" => { "type" => "array", "items" => { "type" => "string" } } },
                      "required" => [ "errors" ]
                    }
                  }
                }
              }
            }
          }
        },
        "/customers/{id}" => {
          "get" => {
            "parameters" => [
              { "name" => "id", "in" => "path", "required" => true, "schema" => { "type" => "number" } },
              { "name" => "expand", "in" => "query", "required" => false, "schema" => { "type" => "boolean" } }
            ],
            "responses" => {
              "200" => {
                "description" => "OK",
                "content" => {
                  "application/json" => { "schema" => { "$ref" => "#/components/schemas/Customer" } }
                }
              }
            }
          }
        }
      },
      "components" => {
        "schemas" => {
          "Customer" => {
            "type" => "object",
            "properties" => { "id" => { "type" => "number" }, "email" => { "type" => "string" } },
            "required" => [ "id" ]
          }
        }
      }
    })
  end
end
