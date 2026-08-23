class SchemaForm::Block
  attr_reader :id, :field, :name, :root

  def initialize(id:, field:, name:, root:)
    @id = id
    @field = field
    @name = name
    @root = root
  end

  def entity?
    name.present?
  end

  def with_root(root)
    self.class.new(id: id, field: field, name: name, root: root)
  end
end
