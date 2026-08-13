require "rails_helper"

describe NotesHelper, type: :helper do
  let(:version) { Version.new }
  let(:attachment) do
    Entity.new(name: "Attachment", root: "{id:number,url:string}", version: version)
  end
  let(:parser) { JSONSchemaParser.new([ attachment ]) }

  def entity_with(root, notes)
    entity = Entity.new(name: "Thing", root: root, version: version)
    allow(entity).to receive(:parsed_root).and_return(parser.parse_value(root))
    allow(entity).to receive(:schema_notes).and_return(
      notes.map { |path, body| SchemaNote.new(path: path, body: body) }
    )
    entity
  end

  def rows(entity, previous = nil, expanded: false)
    value = entity.parsed_root
    value = value.expand if expanded
    lines = value.to_diff(:no_change)
    placed = helper.schema_notes_by_row(entity, previous, lines)
    placed.transform_keys { |row| lines.lines[row].whole_line }.transform_values(&:body)
  end

  it "places a note on the line its path names" do
    entity = entity_with("{id:number,email:string}", { '["email"]' => "lowercased on write" })

    expect(rows(entity)).to eq("email: string" => "lowercased on write")
  end

  it "places a note on a nested attribute's label, not its brace" do
    entity = entity_with("{customer:{city:string}}", { '["customer"]' => "always the billing address" })

    expect(rows(entity)).to eq("customer:" => "always the billing address")
  end

  it "follows an attribute that moved down when another was added above it" do
    entity = entity_with("{added:string,email:string}", { '["email"]' => "still on email" })

    expect(rows(entity)).to eq("email: string" => "still on email")
  end

  it "keeps the note on the reference's own line when it is expanded" do
    entity = entity_with("{file:Attachment}", { '["file"]' => "stored on S3" })

    expect(rows(entity, expanded: true)).to eq("file:" => "stored on S3")
  end

  it "reads a note present on both sides but reworded as changed" do
    before = entity_with("{email:string}", { '["email"]' => "was this" })
    after = entity_with("{email:string}", { '["email"]' => "is now this" })

    note = helper.schema_notes_by_row(after, before, after.parsed_root.to_diff(:no_change)).values.first

    expect([ note.state, note.was, note.body ]).to eq([ :changed, "was this", "is now this" ])
  end

  it "reads a note only the previous version carried as removed" do
    before = entity_with("{email:string}", { '["email"]' => "gone now" })
    after = entity_with("{email:string}", {})

    note = helper.schema_notes_by_row(after, before, after.parsed_root.to_diff(:no_change)).values.first

    expect([ note.state, note.body ]).to eq([ :removed, "gone now" ])
  end

  it "drops a note whose attribute no longer exists" do
    entity = entity_with("{email:string}", { '["renamed_away"]' => "orphaned" })

    expect(rows(entity)).to eq({})
  end
end
