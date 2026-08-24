# Every schema block on the page submits itself with the op, so one edit is
# answered against the whole form rather than the block that was clicked.
class SchemaForm::Blocks
  NEW_ROOT = "string".freeze

  def self.from(submitted)
    new((submitted || {}).each_pair.map do |id, attributes|
      SchemaForm::Block.new(id: id, field: attributes[:field], name: attributes[:name], root: attributes[:root],
                            removed: attributes[:removed].present?, added: attributes[:added].present?)
    end)
  end

  def self.for_entities(entities)
    new(entities.map { |entity| SchemaForm::Block.new(id: nil, field: nil, name: entity.name, root: entity.root) }).renumbering
  end

  def initialize(blocks)
    @blocks = blocks
  end

  def entities
    @blocks.select(&:entity?)
  end

  def fetch(id)
    @blocks.find { |block| block.id == id }
  end

  def replacing(id, root)
    mapping(id) { |block| block.with_root(root) }
  end

  def removing(id)
    mapping(id) { |block| block.with_removed(true) }
  end

  def restoring(id)
    mapping(id) { |block| block.with_removed(false) }
  end

  def adding(name)
    self.class.new(@blocks + [ SchemaForm::Block.new(id: nil, field: nil, name: name, root: NEW_ROOT, added: true) ]).renumbering
  end

  def dropping(id)
    self.class.new(@blocks.reject { |block| block.id == id }).renumbering
  end

  def new_entity_error(name)
    return "An entity name must start with an uppercase letter" unless name.match?(/\A[A-Z]/)
    return "This entity already exists" if entities.reject(&:removed).any? { |block| block.name == name }

    nil
  end

  # A slot is a position in version[entities_attributes], and adding or
  # dropping one moves every slot after it, so the whole list is stamped afresh
  # whenever the set changes.
  def renumbering
    slot = -1
    self.class.new(@blocks.map do |block|
      next block unless block.entity?

      slot += 1
      block.at_slot("entity_root_#{slot}", "version[entities_attributes][#{slot}][root]")
    end)
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

  def referenced?(block)
    version.entity_referenced?(block.name)
  end

  def version
    @version ||= Version.new(entities: records_for(entities.reject(&:removed)))
  end

  # A removed entity keeps whatever it referenced, and what it referenced may
  # itself have been removed by then, so display parses against every name the
  # form still holds rather than against the version being built.
  def parse(block)
    JSONSchemaParser.new(all_records).parse_value(block.root)
  end

  private

  def mapping(id)
    self.class.new(@blocks.map { |block| block.id == id ? yield(block) : block })
  end

  def all_records
    @all_records ||= records_for(entities)
  end

  def records_for(blocks)
    blocks.map { |block| Entity.new(name: block.name, root: block.root) }
  end
end
