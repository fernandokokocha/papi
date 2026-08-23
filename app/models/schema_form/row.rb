class SchemaForm::Row
  attr_reader :kind, :indent, :path, :type, :bracket, :name, :optional, :label, :taken, :removable

  def initialize(kind:, indent:, path:, type: nil, bracket: nil, name: nil, optional: false, label: nil, taken: [], removable: false)
    @kind = kind
    @indent = indent
    @path = path
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
end
