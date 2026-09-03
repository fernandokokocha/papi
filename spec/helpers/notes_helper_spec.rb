require "rails_helper"

describe NotesHelper, type: :helper do
  describe "#schema_notes_by_row" do
    let(:version) { Version.new }
    let(:attachment) { Entity.new(name: "Attachment", root: "{id:number,url:string}", version: version) }

    before { version.entities = [ attachment ] }

    def entity_with(root, notes)
      Entity.new(name: "Thing", root: root, version: version,
                 schema_notes: notes.map { |path, body| SchemaNote.new(path: path, body: body) })
    end

    def placed_notes(entity, previous = nil, expanded: false)
      lines = entity.parsed_root(expanded: expanded).to_diff(:no_change)

      helper.schema_notes_by_row(entity, previous, lines)
        .transform_keys { |row| lines.lines[row].whole_line }
    end

    def note_bodies(entity, previous = nil, expanded: false)
      placed_notes(entity, previous, expanded: expanded).transform_values(&:body)
    end

    it "places a note on the line its path names" do
      entity = entity_with("{id:number,email:string}", { '["email"]' => "lowercased on write" })

      expect(note_bodies(entity)).to eq("email: string" => "lowercased on write")
    end

    it "places every note of an entity that carries several" do
      entity = entity_with("{id:number,email:string,name:string}",
                           { '["id"]' => "assigned by us", '["name"]' => "as the customer typed it" })

      expect(note_bodies(entity)).to eq(
        "id: number" => "assigned by us",
        "name: string" => "as the customer typed it"
      )
    end

    it "places a note on a nested attribute's label, not its brace" do
      entity = entity_with("{customer:{city:string}}", { '["customer"]' => "always the billing address" })

      expect(note_bodies(entity)).to eq("customer:" => "always the billing address")
    end

    it "places a note on an attribute of an array's element" do
      entity = entity_with("{items:[{sku:string}]}", { '["items",null,"sku"]' => "the warehouse's code" })

      expect(note_bodies(entity)).to eq("sku: string" => "the warehouse's code")
    end

    it "places a note on one branch of a one-of" do
      entity = entity_with("{name:(string|null)}", { '["name",1]' => "null while the order is a draft" })

      expect(note_bodies(entity)).to eq("null" => "null while the order is a draft")
    end

    it "places a note whose path is empty on the root's own line" do
      entity = entity_with("{id:number}", { "[]" => "one row of the ledger" })

      expect(note_bodies(entity)).to eq("{" => "one row of the ledger")
    end

    it "follows an attribute that moved down when another was added above it" do
      entity = entity_with("{added:string,email:string}", { '["email"]' => "still on email" })

      expect(note_bodies(entity)).to eq("email: string" => "still on email")
    end

    it "keeps the note on the reference's own line when it is expanded" do
      entity = entity_with("{file:Attachment}", { '["file"]' => "stored on S3" })

      expect(note_bodies(entity, expanded: true)).to eq("file:" => "stored on S3")
    end

    it "reads a note present on both sides but reworded as changed" do
      before = entity_with("{email:string}", { '["email"]' => "was this" })
      after = entity_with("{email:string}", { '["email"]' => "is now this" })

      note = placed_notes(after, before).fetch("email: string")

      expect([ note.state, note.was, note.body ]).to eq([ :changed, "was this", "is now this" ])
    end

    it "reads a note only the previous version carried as removed" do
      before = entity_with("{email:string}", { '["email"]' => "gone now" })
      after = entity_with("{email:string}", {})

      note = placed_notes(after, before).fetch("email: string")

      expect([ note.state, note.body ]).to eq([ :removed, "gone now" ])
    end

    it "drops a note whose attribute no longer exists" do
      entity = entity_with("{email:string}", { '["renamed_away"]' => "orphaned" })

      expect(note_bodies(entity)).to eq({})
    end
  end
end
