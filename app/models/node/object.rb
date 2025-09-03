class Node::Object
  attr_accessor :object_attributes

  def initialize(object_attributes: [])
    @object_attributes = object_attributes
  end

  def to_example_json
    attrs = object_attributes.order(:order).map do |oa|
      oa.to_example_json
    end

    "{ " + attrs.join(", ") + " }"
  end

  def to_diff(change, indent = 0)
    ret = Diff::Lines.new([ Diff::Line.new("{", change, indent) ])

    object_attributes.each do |oa|
      attribute_lines = oa.value.to_diff(change, indent + 1)
      attribute_lines.add_parent(oa.name)
      ret.concat(attribute_lines)
    end

    ret.concat([ Diff::Line.new("}", change, indent) ])
    ret
  end

  def serialize
    "{#{object_attributes.map(&:serialize).join(",")}}"
  end

  def ==(other)
    children_match = object_attributes.zip(other.object_attributes).all? do |attr1, attr2|
      attr1 == attr2
    end
    (self.class == other.class) && children_match
  end

  def expand
    object_expanded = Node::Object.new(
      object_attributes: object_attributes.map { |oa| Node::ObjectAttribute.new(name: oa.name, value: oa.value) }
    )
  end

  def expandable?
    object_attributes.any? { |oa| oa.value.expandable? }
  end
end
