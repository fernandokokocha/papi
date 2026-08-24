# A note addresses one node by the path SchemaNote stores it under — an object
# attribute by name, an array element as null, a one-of branch by index — so it
# travels through the form as the JSON string it is stored as, and neither side
# needs a grammar for it.
SchemaForm::Note = Data.define(:path, :body) do
  def self.for_record(record)
    record.schema_notes.map { |note| new(path: note.path, body: note.body) }
  end

  def self.from(submitted)
    (submitted || {}).each_pair.map { |_index, attributes| new(path: attributes[:path], body: attributes[:body]) }
      .reject { |note| note.body.blank? }
  end

  def to_record
    SchemaNote.new(path: path, body: body)
  end
end
