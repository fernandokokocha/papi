class SchemaForm::Operation
  PRIMITIVE_KINDS = Schema::Parser::PRIMITIVE_KINDS
  STRUCTURES = [ "object", "array", "one-of" ].freeze
  NOTHING = "nothing".freeze
  TYPES = (PRIMITIVE_KINDS + STRUCTURES).freeze

  attr_reader :root

  def initialize(root, entities)
    @root = root
    @entities = entities
  end

  def apply(op, path, value)
    case op
    when "change_type" then change_type(path, value)
    when "rename" then attribute_at(path).name = value
    when "toggle_optional" then attribute_at(path).optional = !attribute_at(path).optional
    when "remove" then remove(path)
    when "add" then add(path)
    end

    root
  end

  private

  def change_type(path, type)
    replacement = build(type)
    return @root = replacement if path.empty?

    parent = node_at(path[0..-2])
    case parent
    when Schema::Node::Object then attribute_at(path).value = replacement
    when Schema::Node::Array then parent.value = replacement
    when Schema::Node::OneOf then parent.branches[path.last.to_i] = replacement
    end
  end

  def remove(path)
    parent = node_at(path[0..-2])
    case parent
    when Schema::Node::Object then parent.object_attributes.delete(attribute_at(path))
    when Schema::Node::OneOf then parent.branches.delete_at(path.last.to_i)
    end
  end

  def add(path)
    node = node_at(path)
    case node
    when Schema::Node::Object
      node.object_attributes << Schema::Node::ObjectAttribute.new(name: unused_name(node), value: Schema::Node::Primitive.new)
    when Schema::Node::OneOf
      node.branches << unused_branch(node.branches)
    end
  end

  def unused_name(node)
    taken = node.object_attributes.map(&:name)
    return "new" unless taken.include?("new")

    (2..).lazy.map { |n| "new#{n}" }.reject { |name| taken.include?(name) }.first
  end

  def unused_branch(branches)
    taken = branches.filter_map { |branch| branch.kind if branch.is_a?(Schema::Node::Primitive) }
    kind = PRIMITIVE_KINDS.find { |k| !taken.include?(k) }

    kind ? Schema::Node::Primitive.new(kind: kind) : Schema::Node::Object.new
  end

  def build(type)
    case type
    when NOTHING then Schema::Node::Nothing.new
    when "object" then Schema::Node::Object.new
    when "array" then Schema::Node::Array.new(value: Schema::Node::Primitive.new)
    when "one-of" then Schema::Node::OneOf.new(branches: [ Schema::Node::Primitive.new(kind: "string"), Schema::Node::Primitive.new(kind: "number") ])
    when *PRIMITIVE_KINDS then Schema::Node::Primitive.new(kind: type)
    else Schema::Node::Entity.new(entity: @entities.find { |entity| entity.name == type })
    end
  end

  def attribute_at(path)
    node_at(path[0..-2]).object_attributes.find { |attribute| attribute.name == path.last }
  end

  def node_at(path)
    path.reduce(@root) { |node, segment| child_of(node, segment) }
  end

  def child_of(node, segment)
    case node
    when Schema::Node::Object then node.object_attributes.find { |attribute| attribute.name == segment }.value
    when Schema::Node::Array then node.value
    when Schema::Node::OneOf then node.branches[segment.to_i]
    end
  end
end
