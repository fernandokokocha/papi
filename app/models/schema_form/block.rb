class SchemaForm::Block
  ENDPOINT_KEY = /\Aendpoint_(?:input|output)_(\d+)/

  attr_reader :id, :field, :notes_field, :name_field, :name, :root, :notes, :removed, :added

  def initialize(id:, field:, name:, root:, notes_field: nil, name_field: nil, notes: [], removed: false,
                 added: false)
    @id = id
    @field = field
    @notes_field = notes_field
    @name_field = name_field
    @name = name
    @root = root
    @notes = notes
    @removed = removed
    @added = added
  end

  def entity?
    name.present?
  end

  def belongs_to_endpoint?(key)
    id == SchemaForm::Blocks.input_id(key) || id.start_with?(SchemaForm::Blocks.output_id(key, ""))
  end

  # An entity block is a card of its own; a schema block draws inside the card
  # of the endpoint whose key it was stamped with.
  def endpoint_key
    id[ENDPOINT_KEY, 1]
  end

  def note_at(path)
    notes.find { |note| note.path == path }
  end

  def with_root(root)
    copy(root: root)
  end

  # Clearing the text is how a note is taken off a node — there is no separate
  # control for it, and an empty note is not a thing the version can hold.
  def with_note(path, body)
    kept = notes.reject { |note| note.path == path }
    copy(notes: body.present? ? kept + [ SchemaForm::Note.new(path: path, body: body) ] : kept)
  end

  # A note whose node the last op took away has nothing left to point at, so it
  # goes with it rather than riding on as an orphan nothing can render.
  def keeping_notes_at(paths)
    copy(notes: notes.select { |note| paths.include?(note.path) })
  end

  def with_removed(removed)
    copy(removed: removed)
  end

  def at_slot(id:, field:, name_field:, notes_field:)
    copy(id: id, field: field, name_field: name_field, notes_field: notes_field)
  end

  private

  def copy(**changes)
    self.class.new(**{ id: id, field: field, notes_field: notes_field, name_field: name_field, name: name,
                       root: root, notes: notes, removed: removed, added: added }, **changes)
  end
end
