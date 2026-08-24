# Every schema block on the page submits itself with the op, so one edit is
# answered against the whole form rather than the block that was clicked. A
# block is its root and the notes pinned inside it, because both are edited
# here and both go into the version this form cuts.
class SchemaForm::Blocks
  NEW_ROOT = "string".freeze

  def self.from(submitted)
    new((submitted || {}).each_pair.map do |id, attributes|
      SchemaForm::Block.new(id: id, field: attributes[:field], notes_field: attributes[:notes_field],
                            name: attributes[:name], root: attributes[:root],
                            notes: SchemaForm::Note.from(attributes[:notes]),
                            removed: attributes[:removed].present?, added: attributes[:added].present?)
    end)
  end

  def self.for_entities(entities)
    new(entities.map do |entity|
      SchemaForm::Block.new(id: nil, field: nil, name: entity.name, root: entity.root,
                            notes: SchemaForm::Note.for_record(entity))
    end).renumbering
  end

  def self.for_version(version)
    for_entities(version.entities) + new(version.endpoints.each_with_index.flat_map do |endpoint, index|
      key = index.to_s
      [ input_block(key, endpoint.input, SchemaForm::Note.for_record(endpoint)) ] +
        endpoint.responses.sort_by(&:code).map do |response|
          output_block(key, response.code, response.output, SchemaForm::Note.for_record(response))
        end
    end)
  end

  def self.input_block(key, root, notes = [])
    SchemaForm::Block.new(id: input_id(key), field: "version[endpoints_attributes][][input]",
                          notes_field: "version[endpoints_attributes][][schema_notes]",
                          name: nil, root: root, notes: notes)
  end

  def self.output_block(key, code, root, notes = [])
    SchemaForm::Block.new(id: output_id(key, code), name: nil, root: root, notes: notes,
                          field: "version[endpoints_attributes][][responses][#{code}][output]",
                          notes_field: "version[endpoints_attributes][][responses][#{code}][schema_notes]")
  end

  def self.input_id(key)
    "endpoint_input_#{key}"
  end

  def self.output_id(key, code)
    "endpoint_output_#{key}_#{code}"
  end

  def initialize(blocks)
    @blocks = blocks
  end

  def +(other)
    self.class.new(@blocks + other.to_a)
  end

  def to_a
    @blocks
  end

  def entities
    @blocks.select(&:entity?)
  end

  def input_for(key)
    fetch(self.class.input_id(key))
  end

  def output_for(key, code)
    fetch(self.class.output_id(key, code))
  end

  def adding_output(key, code)
    self.class.new(@blocks + [ self.class.output_block(key, code, "") ])
  end

  def adding_endpoint(key)
    self.class.new(@blocks + [ self.class.input_block(key, "") ])
  end

  def dropping_endpoint(key)
    self.class.new(@blocks.reject { |block| block.belongs_to_endpoint?(key) })
  end

  def removing_endpoint(key)
    mapping_endpoint(key) { |block| block.with_removed(true) }
  end

  def restoring_endpoint(key)
    mapping_endpoint(key) { |block| block.with_removed(false) }
  end

  def fetch(id)
    @blocks.find { |block| block.id == id }
  end

  def replacing(id, root)
    mapping(id) { |block| block.with_root(root).keeping_notes_at(note_paths(root)) }
  end

  def noting(id, path, body)
    mapping(id) { |block| block.with_note(path, body) }
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

  def removed_twin(name)
    entities.find { |block| block.removed && block.name == name }
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
      block.at_slot("entity_root_#{slot}", "version[entities_attributes][#{slot}][root]",
                    "version[entities_attributes][#{slot}][schema_notes_attributes]")
    end)
  end

  def locals_for(block)
    { root: parse(block), block: block, referenceable_names: referenceable_names(block), nothing: !block.entity? }
  end

  def referenceable_names(block)
    version.referenceable_entity_names(block.name)
  end

  def referenced?(block)
    version.entity_referenced?(block.name) ||
      schemas.any? { |schema| parse(schema).entity_names.include?(block.name) }
  end

  def version
    @version ||= Version.new(entities: entities.reject(&:removed).map { |block| build_record(block) })
  end

  # A removed entity keeps whatever it referenced, and what it referenced may
  # itself have been removed by then, so display parses against every name the
  # form still holds rather than against the version being built.
  def parse(block)
    parser = JSONSchemaParser.new(all_records)
    block.entity? ? parser.parse_value(block.root) : parser.parse_whole_value(block.root)
  end

  # Diffing asks the two entities whether they differ, and a note is half of
  # that answer — so the stand-in carries the notes the form holds, or a
  # reference to a noted entity reads as changed on a form nobody has touched.
  def record_for(block)
    all_records.find { |record| record.name == block.name }
  end

  private

  # A removed endpoint is not going into the version, so what its schemas name
  # is not a reason to keep an entity.
  def schemas
    @blocks.reject(&:entity?).reject(&:removed)
  end

  def note_paths(root)
    SchemaForm::Rows.for(parse_against_all(root)).filter_map(&:note_path).map { |path| SchemaNote.serialize_path(path) }
  end

  def parse_against_all(root)
    JSONSchemaParser.new(all_records).parse_whole_value(root)
  end

  def mapping(id)
    self.class.new(@blocks.map { |block| block.id == id ? yield(block) : block })
  end

  def mapping_endpoint(key)
    self.class.new(@blocks.map { |block| block.belongs_to_endpoint?(key) ? yield(block) : block })
  end

  # Diffing a reference asks the entity it names for its own root, so every
  # record the parser is handed has to sit in a version that can resolve it.
  def all_records
    @all_records ||= Version.new(entities: entities.map { |block| build_record(block) }).entities
  end

  def build_record(block)
    Entity.new(name: block.name, root: block.root, schema_notes: block.notes.map(&:to_record))
  end
end
