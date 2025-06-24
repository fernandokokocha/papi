class EntityNode < ApplicationRecord
  belongs_to :entity

  def to_diff(change, indent = 0)
    Diff::Lines.new([ Diff::Line.new(entity.name, change, indent) ])
  end

  def expand
    entity.root
  end
end
