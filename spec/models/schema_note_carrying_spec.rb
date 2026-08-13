require "rails_helper"

# Cutting a new version amoeba_dups the whole spec, and notes have to ride
# along or they die at every version boundary. Nesting is what breaks it:
# a response sits two levels below the version.
describe Version, "carrying schema notes into a duplicate" do
  let(:version) { FactoryBot.create(:version, name: "v1") }
  let(:endpoint) { FactoryBot.create(:endpoint, version: version, input: "{email:string}") }
  let(:entity) { Entity.create!(version: version, name: "User", root: "{id:number}") }
  let(:response) { FactoryBot.create(:response, endpoint: endpoint, output: "{id:number}") }

  def notes_of(copy)
    {
      endpoint: copy.endpoints.flat_map(&:schema_notes).map(&:body),
      entity: copy.entities.flat_map(&:schema_notes).map(&:body),
      response: copy.endpoints.flat_map(&:responses).flat_map(&:schema_notes).map(&:body)
    }
  end

  it "copies notes on every notable, however deeply nested" do
    endpoint.schema_notes.create!(path: '["email"]', body: "on the endpoint input")
    entity.schema_notes.create!(path: '["id"]', body: "on the entity root")
    response.schema_notes.create!(path: '["id"]', body: "on the response output")

    copy = version.reload.amoeba_dup
    copy.name = "v2"
    copy.save!

    expect(notes_of(copy)).to eq(
      endpoint: [ "on the endpoint input" ],
      entity: [ "on the entity root" ],
      response: [ "on the response output" ]
    )
  end

  it "gives the copy its own notes, so editing the draft leaves the published version alone" do
    endpoint.schema_notes.create!(path: '["email"]', body: "original")

    copy = version.reload.amoeba_dup
    copy.name = "v2"
    copy.save!
    copy.endpoints.first.schema_notes.first.update!(body: "reworded in the draft")

    expect(endpoint.schema_notes.reload.map(&:body)).to eq([ "original" ])
  end
end
