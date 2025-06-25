class Node::Entity < ApplicationRecord
  self.table_name = "entity_nodes"

  belongs_to :entity

  def to_diff(change, indent = 0)
    Diff::Lines.new([ Diff::Line.new(entity.name, change, indent) ])
  end

  def serialize
    entity.name
  end

  def expand
    entity.root
  end

  def expandable?
    true
  end
end
