class SchemaForm::Rows
  ARRAY_SEGMENT = "[]".freeze

  def self.for(root)
    new(root).to_a
  end

  def initialize(root)
    @root = root
  end

  def to_a
    rows_for(@root, [], [], 0)
  end

  private

  # A named attribute whose value is a block reads over two lines, exactly as
  # Diff::Lines lays it out: the label, then the opening bracket. The first row
  # a node emits is the one that carries its name and its controls.
  #
  # An op addresses a node one way and a note another — a one-of branch is
  # "0" to the first and 0 to the second, an array element "[]" and null — so
  # both paths are carried down rather than one being derived from the other.
  def rows_for(node, path, note_path, indent, name: nil, optional: false, **identity)
    return [ leaf(node, path, note_path, indent, name: name, optional: optional, **identity) ] if leaf?(node)
    return block(node, path, note_path, indent, **identity) if name.nil?

    [ label(path, note_path, indent, name, optional, **identity) ] +
      block(node, path, note_path, indent, labelled: true, **identity.slice(:taken))
  end

  # Both rows of a labelled block name the same node, and a note belongs on the
  # first — which is what Schema::PathIndex reads back off the rendered lines.
  def block(node, path, note_path, indent, labelled: false, **identity)
    opening_note_path = labelled ? nil : note_path

    case node
    when Schema::Node::Object
      inside = node.object_attributes.flat_map do |attribute|
        rows_for(attribute.value, path + [ attribute.name ], note_path + [ attribute.name ], indent + 1,
                 name: attribute.name, optional: attribute.optional, removable: true)
      end
      [ opening("object", "{", path, opening_note_path, indent, **identity) ] + inside +
        [ add(path, indent + 1, "attribute"), closing("}", path, indent) ]
    when Schema::Node::Array
      [ opening("array", "[", path, opening_note_path, indent, **identity) ] +
        rows_for(node.value, path + [ ARRAY_SEGMENT ], note_path + [ nil ], indent + 1) +
        [ closing("]", path, indent) ]
    when Schema::Node::OneOf
      inside = node.branches.each_with_index.flat_map do |branch, index|
        rows_for(branch, path + [ index.to_s ], note_path + [ index ], indent + 1,
                 taken: named_types(node.branches) - [ named_type(branch) ],
                 removable: node.branches.size > 2)
      end
      [ opening("one-of", "(", path, opening_note_path, indent, **identity) ] + inside +
        [ add(path, indent + 1, "branch"), closing(")", path, indent) ]
    end
  end

  def leaf?(node)
    node.is_a?(Schema::Node::Primitive) || node.is_a?(Schema::Node::Entity) || node.is_a?(Schema::Node::Nothing)
  end

  def named_types(branches)
    branches.filter_map { |branch| named_type(branch) }
  end

  def named_type(branch)
    case branch
    when Schema::Node::Primitive then branch.kind
    when Schema::Node::Entity then branch.entity.name
    end
  end

  def leaf(node, path, note_path, indent, **row)
    SchemaForm::Row.new(kind: :node, indent: indent, path: path, note_path: note_path, type: type_of(node), **row)
  end

  def type_of(node)
    case node
    when Schema::Node::Entity then node.entity.name
    when Schema::Node::Nothing then SchemaForm::Operation::NOTHING
    else node.kind
    end
  end

  def label(path, note_path, indent, name, optional, **identity)
    SchemaForm::Row.new(kind: :node, indent: indent, path: path, note_path: note_path, name: name,
                        optional: optional, **identity.except(:taken))
  end

  def opening(type, bracket, path, note_path, indent, **identity)
    SchemaForm::Row.new(kind: :node, indent: indent, path: path, note_path: note_path, type: type,
                        bracket: bracket, **identity)
  end

  def closing(bracket, path, indent)
    SchemaForm::Row.new(kind: :close, indent: indent, path: path, bracket: bracket)
  end

  def add(path, indent, label)
    SchemaForm::Row.new(kind: :add, indent: indent, path: path, label: label)
  end
end
