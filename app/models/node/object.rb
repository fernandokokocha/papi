class Node::Object < ApplicationRecord
  self.table_name = "object_nodes"

  has_many :object_attributes, foreign_key: :parent_id, dependent: :destroy

  def to_example_json
    attrs = object_attributes.order(:order).map do |oa|
      oa.to_example_json
    end

    "{ " + attrs.join(", ") + " }"
  end

  def to_diff(change, indent = 0)
    ret = Diff::Lines.new([ Diff::Line.new("{", change, indent) ])

    object_attributes.sort_by(&:order).each do |oa|
      attribute_lines = oa.value.to_diff(change, indent + 1)
      attribute_lines.add_parent(oa.name)
      ret.concat(attribute_lines)
    end

    ret.concat([ Diff::Line.new("}", change, indent) ])
    ret
  end

  def serialize
    "{ #{object_attributes.order(:order).map(&:serialize).join(", ")} }"
  end

  def ==(other)
    children_match = object_attributes.all? do |attr|
      found = other.object_attributes.where(name: attr.name).first
      found && found.value == attr.value
    end
    (self.class == other.class) && children_match
  end

  def expand
    object_expanded = Node::Object.new
    object_attributes.sort_by(&:order).each do |oa|
      object_expanded.object_attributes.build(name: oa.name,
                                              value: oa.value.expand,
                                              order: oa.order,
                                              parent: object_expanded)
    end
    object_expanded
  end

  def expandable?
    object_attributes.any? { |oa| oa.value.expandable? }
  end
end
