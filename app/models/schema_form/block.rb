class SchemaForm::Block
  attr_reader :id, :field, :name, :root, :removed, :added

  def initialize(id:, field:, name:, root:, removed: false, added: false)
    @id = id
    @field = field
    @name = name
    @root = root
    @removed = removed
    @added = added
  end

  def entity?
    name.present?
  end

  def belongs_to_endpoint?(key)
    id == SchemaForm::Blocks.input_id(key) || id.start_with?(SchemaForm::Blocks.output_id(key, ""))
  end

  def with_root(root)
    copy(root: root)
  end

  def with_removed(removed)
    copy(removed: removed)
  end

  def at_slot(id, field)
    copy(id: id, field: field)
  end

  private

  def copy(**changes)
    self.class.new(**{ id: id, field: field, name: name, root: root, removed: removed, added: added }, **changes)
  end
end
