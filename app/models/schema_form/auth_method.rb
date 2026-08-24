class SchemaForm::AuthMethod
  attr_reader :name, :kind, :note, :removed, :added

  def initialize(name:, kind:, note:, removed: false, added: false)
    @name = name
    @kind = kind
    @note = note
    @removed = removed
    @added = added
  end

  def same_contract_as?(other)
    name == other.name && kind == other.kind
  end

  def with_removed(removed)
    self.class.new(name: name, kind: kind, note: note, removed: removed, added: added)
  end
end
