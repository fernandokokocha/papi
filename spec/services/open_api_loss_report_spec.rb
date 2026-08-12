require "rails_helper"

# Importing and exporting is not a round trip and never asserts identity. This
# reads the other way round: the exported document is the report of what Papi
# kept, and every difference from the source below is an agreed loss.
describe "Importing an OpenAPI document and exporting it back" do
  let(:group) { FactoryBot.create(:group) }
  let(:user) { FactoryBot.create(:user, group: group) }
  let(:project) { FactoryBot.create(:project, name: "Shop", group: group) }

  let(:source) do
    <<~YAML
      openapi: 3.0.3
      info:
        title: Shop API
        version: 2.4.1
        description: Everything the storefront needs
        contact:
          email: api@shop.example
      servers:
        - url: https://api.shop.example/v2
      tags:
        - name: customers
      security:
        - bearerAuth: []
      paths:
        /customers:
          get:
            operationId: listCustomers
            tags: [customers]
            summary: List customers
            description: Ordered by signup date
            parameters:
              - name: page
                in: query
                required: false
                schema:
                  type: integer
                  format: int32
                  default: 1
              - name: X-Request-Id
                in: header
                schema:
                  type: string
            responses:
              "200":
                description: The customers
                headers:
                  X-Total-Count:
                    schema:
                      type: integer
                content:
                  application/json:
                    schema:
                      type: array
                      items:
                        $ref: "#/components/schemas/Customer"
              "2XX":
                description: Some other success
              default:
                description: Anything else
          post:
            summary: Register a customer
            requestBody:
              required: true
              content:
                application/json:
                  schema:
                    $ref: "#/components/schemas/CustomerInput"
                application/xml:
                  schema:
                    type: string
            responses:
              "201":
                description: The new customer
                content:
                  application/json:
                    schema:
                      $ref: "#/components/schemas/Customer"
          head:
            responses:
              "200":
                description: Nothing at all
        /customers/{customer-id}:
          parameters:
            - name: customer-id
              in: path
              required: true
              schema:
                type: integer
          get:
            deprecated: true
            responses:
              "200":
                description: OK
                content:
                  application/json:
                    schema:
                      $ref: "#/components/schemas/Customer"
          delete:
            responses:
              default:
                description: Gone, one way or another
        /avatars/{name}.{ext}:
          get:
            responses:
              "200":
                description: The avatar
        /uploads:
          post:
            requestBody:
              content:
                multipart/form-data:
                  schema:
                    type: object
                    properties:
                      file:
                        type: string
                        format: binary
            responses:
              "204":
                description: Stored
      components:
        securitySchemes:
          bearerAuth:
            type: http
            scheme: bearer
        schemas:
          CustomerInput:
            type: object
            required: [email]
            properties:
              email:
                type: string
                format: email
                example: someone@example.com
          Customer:
            allOf:
              - $ref: "#/components/schemas/CustomerInput"
              - type: object
                required: [id, tier]
                properties:
                  id:
                    type: integer
                    format: int64
                    readOnly: true
                  tier:
                    type: string
                    enum: [free, paid]
                  nickname:
                    type: string
                    nullable: true
                  address:
                    $ref: "#/components/schemas/Address"
          Address:
            type: object
            required: [city]
            properties:
              city:
                type: string
    YAML
  end

  # Export publishes a version, so the imported candidate is merged first —
  # import, review, merge, export is the whole way round.
  def exported
    service = OpenAPI::Import.new(project, source, author: user)
    service.call
    Candidate::Merge.new(service.candidate, decided_by: user).call

    OpenAPI::Export.new(service.candidate.latest_version.reload).call
  end

  it "keeps the paths, the schemas and nothing Papi cannot hold" do
    expect(exported).to eq({
      "openapi" => "3.1.0",
      # info is synthesized: the project and the published version, never the
      # source's title, version, description or contact.
      "info" => { "title" => "Shop", "version" => "v1" },
      "paths" => {
        # /avatars/{name}.{ext} is gone — two params in one segment cannot route.
        "/customers" => {
          # head is gone; operationId, tags and the header param with it.
          "get" => {
            "summary" => "List customers — Ordered by signup date",
            # The document's root security reaches every operation: Papi has no
            # version-wide default, so each endpoint states it for itself.
            "security" => [ { "bearerAuth" => [] } ],
            "parameters" => [
              { "name" => "page", "in" => "query", "required" => false, "schema" => { "type" => "number" } }
            ],
            "responses" => {
              # 2XX and default are gone: Papi keys a response by status code.
              "200" => {
                "description" => "The customers",
                "content" => {
                  "application/json" => {
                    "schema" => { "type" => "array", "items" => { "$ref" => "#/components/schemas/Customer" } }
                  }
                }
              }
            }
          },
          "post" => {
            "summary" => "Register a customer",
            "security" => [ { "bearerAuth" => [] } ],
            "requestBody" => {
              "required" => true,
              "content" => {
                "application/json" => { "schema" => { "$ref" => "#/components/schemas/CustomerInput" } }
              }
            },
            "responses" => {
              "201" => {
                "description" => "The new customer",
                "content" => {
                  "application/json" => { "schema" => { "$ref" => "#/components/schemas/Customer" } }
                }
              }
            }
          }
        },
        # customer-id is not a name Papi can spell, so it is renamed.
        "/customers/{customer_id}" => {
          # An endpoint the editor could not open is worse than an imprecise
          # code, so the only response Papi could not key became a 200.
          "delete" => {
            "security" => [ { "bearerAuth" => [] } ],
            "parameters" => [
              { "name" => "customer_id", "in" => "path", "required" => true, "schema" => { "type" => "number" } }
            ],
            "responses" => { "200" => { "description" => "Gone, one way or another" } }
          },
          "get" => {
            "security" => [ { "bearerAuth" => [] } ],
            "parameters" => [
              { "name" => "customer_id", "in" => "path", "required" => true, "schema" => { "type" => "number" } }
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
        },
        "/uploads" => {
          # The multipart body is not JSON, so the endpoint declares no input.
          "post" => {
            "security" => [ { "bearerAuth" => [] } ],
            "responses" => { "204" => { "description" => "Stored" } }
          }
        }
      },
      "components" => {
        # type: http with a bearer or basic scheme is all Papi holds; the
        # scheme's own name survives, since it is what clients were told.
        "securitySchemes" => {
          "bearerAuth" => { "type" => "http", "scheme" => "bearer" }
        },
        "schemas" => {
          "Address" => {
            "type" => "object",
            "properties" => { "city" => { "type" => "string" } },
            "required" => [ "city" ]
          },
          # allOf is flattened, which inlines CustomerInput's email and loses
          # that reference. format, readOnly and example are gone, the enum is
          # its base type, and nullable became a null branch.
          "Customer" => {
            "type" => "object",
            "properties" => {
              "email" => { "type" => "string" },
              "id" => { "type" => "number" },
              "tier" => { "type" => "string" },
              "nickname" => { "oneOf" => [ { "type" => "string" }, { "type" => "null" } ] },
              "address" => { "$ref" => "#/components/schemas/Address" }
            },
            "required" => [ "email", "id", "tier" ]
          },
          "CustomerInput" => {
            "type" => "object",
            "properties" => { "email" => { "type" => "string" } },
            "required" => [ "email" ]
          }
        }
      }
    })
  end
end
