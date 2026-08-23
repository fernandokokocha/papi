class SchemaForm::Rows
  ARRAY_SEGMENT = "[]".freeze

  def self.for(root)
    new(root).to_a
  end

  def initialize(root)
    @root = root
  end

  def to_a
    rows_for(@root, [], 0)
  end

  private

  # A named attribute whose value is a block reads over two lines, exactly as
  # Diff::Lines lays it out: the label, then the opening bracket. The first row
  # a node emits is the one that carries its name and its controls.
  def rows_for(node, path, indent, name: nil, optional: false, **identity)
    return [ leaf(node, path, indent, name: name, optional: optional, **identity) ] if leaf?(node)
    return block(node, path, indent, **identity) if name.nil?

    [ label(path, indent, name, optional, **identity) ] + block(node, path, indent, **identity.slice(:taken))
  end

  def block(node, path, indent, **identity)
    case node
    when Node::Object
      inside = node.object_attributes.flat_map do |attribute|
        rows_for(attribute.value, path + [ attribute.name ], indent + 1,
                 name: attribute.name, optional: attribute.optional, removable: true)
      end
      [ opening("object", "{", path, indent, **identity) ] + inside +
        [ add(path, indent + 1, "attribute"), closing("}", path, indent) ]
    when Node::Array
      [ opening("array", "[", path, indent, **identity) ] +
        rows_for(node.value, path + [ ARRAY_SEGMENT ], indent + 1) +
        [ closing("]", path, indent) ]
    when Node::OneOf
      inside = node.branches.each_with_index.flat_map do |branch, index|
        rows_for(branch, path + [ index.to_s ], indent + 1,
                 taken: named_types(node.branches) - [ named_type(branch) ],
                 removable: node.branches.size > 2)
      end
      [ opening("one-of", "(", path, indent, **identity) ] + inside +
        [ add(path, indent + 1, "branch"), closing(")", path, indent) ]
    end
  end

  def leaf?(node)
    node.is_a?(Node::Primitive) || node.is_a?(Node::Entity)
  end

  def named_types(branches)
    branches.filter_map { |branch| named_type(branch) }
  end

  def named_type(branch)
    case branch
    when Node::Primitive then branch.kind
    when Node::Entity then branch.entity.name
    end
  end

  def leaf(node, path, indent, **row)
    type = node.is_a?(Node::Entity) ? node.entity.name : node.kind
    SchemaForm::Row.new(kind: :node, indent: indent, path: path, type: type, **row)
  end

  def label(path, indent, name, optional, **identity)
    SchemaForm::Row.new(kind: :node, indent: indent, path: path, name: name, optional: optional,
                        **identity.except(:taken))
  end

  def opening(type, bracket, path, indent, **identity)
    SchemaForm::Row.new(kind: :node, indent: indent, path: path, type: type, bracket: bracket, **identity)
  end

  def closing(bracket, path, indent)
    SchemaForm::Row.new(kind: :close, indent: indent, path: path, bracket: bracket)
  end

  def add(path, indent, label)
    SchemaForm::Row.new(kind: :add, indent: indent, path: path, label: label)
  end
end
