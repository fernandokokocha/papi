class SchemaForm::Row
  attr_reader :kind, :indent, :path, :note_path, :type, :bracket, :name, :optional, :label, :taken, :removable

  def initialize(kind:, indent:, path:, note_path: nil, type: nil, bracket: nil, name: nil, optional: false,
                 label: nil, taken: [], removable: false)
    @kind = kind
    @indent = indent
    @path = path
    @note_path = note_path
    @type = type
    @bracket = bracket
    @name = name
    @optional = optional
    @label = label
    @taken = taken
    @removable = removable
  end

  def numbered?
    kind != :add
  end

  def named?
    !name.nil?
  end

  def notable?
    !note_path.nil?
  end

  def note_key
    SchemaNote.serialize_path(note_path)
  end
end
