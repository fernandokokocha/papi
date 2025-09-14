class Node::Entity
  attr_accessor :entity

  def initialize(entity: Node::Nothing.new)
    @entity = entity
  end

  def to_diff(change, indent = 0)
    Diff::Lines.new([ Diff::Line.new(entity.name, change, indent) ])
  end

  def serialize
    entity.name
  end

  def expand
    entity.parsed_root
  end

  def expandable?
    true
  end

  def ==(other)
    (self.class == other.class) && (self.entity == other.entity)
  end

  def to_example_json
    entity.parsed_root.to_example_json
  end
end
