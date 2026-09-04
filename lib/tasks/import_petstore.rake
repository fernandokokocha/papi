namespace :dev do
  desc "Fill the Petstore project by importing test/fixtures/files/petstore.json, twice"
  task import_petstore: :environment do
    project = Project.find_by!(name: "Petstore")
    author = User.find_by!(email_address: "tomek@drugowcy.dev")
    reviewer = User.find_by!(email_address: "mira@drugowcy.dev")
    document = JSON.parse(Rails.root.join("test/fixtures/files/petstore.json").read)

    published = import_document(project, document, author: author, at: "2025-09-18 10:30:00")
    Candidate::Merge.new(published, decided_by: reviewer).call
    published.update!(decided_at: "2025-09-22 14:05:00")
    published.version.update!(created_at: "2025-09-22 14:05:00", release_notes: <<~NOTES)
      Imported wholesale from the Petstore team's own OpenAPI document, unedited.

      Three things did not survive the import. The oauth2 and apiKey schemes have no equivalent here, so every operation that asked for one now reads as needing no auth at all. GET /store/inventory declared a map of status to count, and a map is not a type Papi holds, so its body arrives empty.
    NOTES

    proposed = import_document(project, revised(document), author: author, at: "2025-10-22 09:15:00")
    proposed.version.update!(created_at: "2025-10-22 09:15:00", release_notes: <<~NOTES)
      The Petstore team's document as of October, imported over v1.

      A pet carries a description and a birth date; an order carries its currency and total. Photos are readable on their own now. GET /user/logout is gone — it never did anything a client could observe.
    NOTES
    proposed.approvals.create!(user: reviewer, created_at: "2025-10-23 11:40:00")

    puts "Petstore: #{published.version.name} published, #{proposed.name} open"
  end

  def import_document(project, document, author:, at:)
    import = OpenAPI::Import.new(project, JSON.generate(document), author: author)
    import.call
    import.candidate.tap { |candidate| candidate.update!(created_at: at) }
  end

  # What the Petstore team changed between the two documents. Written as a patch
  # rather than as a second checked-in file so the delta is the readable thing.
  def revised(document)
    revised = document.deep_dup
    paths = revised["paths"]
    schemas = revised.dig("components", "schemas")

    schemas["Pet"]["properties"]["description"] = { "type" => "string" }
    schemas["Pet"]["properties"]["birthDate"] = { "type" => "string", "format" => "date" }
    schemas["Order"]["properties"]["currency"] = { "type" => "string", "example" => "USD" }
    schemas["Order"]["properties"]["total"] = { "type" => "integer", "format" => "int32" }

    paths.delete("/user/logout")
    paths["/pet/{petId}/photos"] = {
      "get" => {
        "tags" => [ "pet" ],
        "summary" => "List a pet's photos",
        "parameters" => [
          { "name" => "petId", "in" => "path", "required" => true,
            "schema" => { "type" => "integer", "format" => "int64" } }
        ],
        "responses" => {
          "200" => {
            "description" => "Successful operation",
            "content" => {
              "application/json" => {
                "schema" => { "type" => "array", "items" => { "type" => "string" } }
              }
            }
          },
          "404" => { "description" => "Pet not found" }
        },
        "security" => [ { "storeToken" => [] } ]
      }
    }

    revised.dig("components", "securitySchemes", "storeToken")["description"] =
      "Store token, sent as `Authorization: Bearer …`. Ordering, photos and user management use it."

    revised
  end
end
