# Every schema block on the page submits itself with the op, so one edit is
# answered against the whole form rather than the block that was clicked.
class SchemaForm::Blocks
  def self.from(submitted)
    new(submitted.each_pair.map do |id, attributes|
      SchemaForm::Block.new(id: id, field: attributes[:field], name: attributes[:name], root: attributes[:root])
    end)
  end

  def initialize(blocks)
    @blocks = blocks
  end

  def fetch(id)
    @blocks.find { |block| block.id == id }
  end

  def replacing(id, root)
    self.class.new(@blocks.map { |block| block.id == id ? block.with_root(root) : block })
  end

  def changed_since(previous)
    @blocks.select do |block|
      was = previous.fetch(block.id)
      block.root != was.root || referenceable_names(block) != previous.referenceable_names(was)
    end
  end

  def locals_for(block)
    { root: parse(block), id: block.id, field: block.field, name: block.name,
      referenceable_names: referenceable_names(block) }
  end

  def referenceable_names(block)
    version.referenceable_entity_names(block.name)
  end

  def version
    @version ||= Version.new(entities: @blocks.select(&:entity?).map { |block| Entity.new(name: block.name, root: block.root) })
  end

  def parse(block)
    JSONSchemaParser.new(version.entities).parse_value(block.root)
  end
end
