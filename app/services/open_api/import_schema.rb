class OpenAPI::ImportSchema
  REF_PREFIX = "#/components/schemas/"
  KINDS = {
    "string" => "string",
    "number" => "number",
    "integer" => "number",
    "boolean" => "boolean",
    "null" => "null"
  }.freeze
  UNTYPED_KIND = "string"

  # Descriptions are collected as the walk goes, keyed by the same path a note
  # stores. One-of branches are left out on purpose: one_of flattens, dedups and
  # reorders them, so a branch index here would not name the branch that lands.
  attr_reader :notes

  def initialize(schema, entities = {}, schemas = {}, notes = {}, path = [])
    @schema = schema
    @entities = entities
    @schemas = schemas
    @notes = notes
    @path = path
  end

  def call
    note = @schema["description"]
    @notes[@path] = note if note.present?

    @schema["nullable"] ? with_null(typed) : typed
  end

  private

  def typed
    return entity if @schema.key?("$ref")
    return one_of(branches) if branches.present?
    return all_of if @schema["allOf"].present?
    return one_of(type.map { |name| @schema.merge("type" => name) }) if type.is_a?(::Array)
    return object if object_schema?(@schema)
    return array if type == "array"

    Node::Primitive.new(kind: kind)
  end

  def type
    @schema["type"]
  end

  def branches
    @schema["oneOf"] || @schema["anyOf"]
  end

  def object_schema?(schema)
    schema["type"] == "object" || (schema["type"].nil? && schema.key?("properties"))
  end

  def object
    required = @schema["required"] || []
    attributes = (@schema["properties"] || {}).map do |name, value|
      Node::ObjectAttribute.new(name: name, value: node_for(value, name), optional: !required.include?(name))
    end

    Node::Object.new(object_attributes: attributes)
  end

  def array
    Node::Array.new(value: node_for(@schema["items"] || {}, nil))
  end

  # An enum without a type still has one — the type of the values it lists.
  def kind
    return KINDS.fetch(type, UNTYPED_KIND) if type
    return UNTYPED_KIND if @schema["enum"].blank?

    case @schema["enum"].first
    when ::String then "string"
    when ::Numeric then "number"
    when true, false then "boolean"
    else UNTYPED_KIND
    end
  end

  def entity
    reference = @schema["$ref"]
    name = reference.delete_prefix(REF_PREFIX)
    raise OpenAPI::Invalid, "Cannot resolve the reference #{reference}" unless reference.start_with?(REF_PREFIX) && @entities.key?(name)

    Node::Entity.new(entity: @entities.fetch(name))
  end

  # allOf composes objects, so importing it means merging them into one. A
  # branch is resolved one level, the same depth an entity expands to.
  def all_of
    objects = @schema["allOf"].map { |branch| resolved(branch) }.select { |branch| object_schema?(branch) }

    node_for(
      "type" => "object",
      "properties" => objects.reduce({}) { |merged, branch| merged.merge(branch["properties"] || {}) },
      "required" => objects.flat_map { |branch| branch["required"] || [] }
    )
  end

  def resolved(branch)
    return branch unless branch.key?("$ref")

    @schemas.fetch(branch["$ref"].delete_prefix(REF_PREFIX), {})
  end

  def with_null(node)
    one_of_nodes(flattened(node) + [ Node::Primitive.new(kind: "null") ])
  end

  def one_of(schemas)
    one_of_nodes(schemas.flat_map { |schema| flattened(node_for(schema)) })
  end

  # A branch may not itself be a one-of, and no two branches may share a named
  # type — the shape the editor enforces.
  def one_of_nodes(nodes)
    branches = nodes.each_with_index.uniq { |node, index| named(node) || index }.map(&:first)

    branches.one? ? branches.first : Node::OneOf.new(branches: branches)
  end

  def flattened(node)
    node.is_a?(Node::OneOf) ? node.branches : [ node ]
  end

  def named(node)
    node.serialize if node.is_a?(Node::Primitive) || node.is_a?(Node::Entity)
  end

  # A branch, an allOf merge and a nullable wrapper all rebuild the tree, so
  # they walk without a path and their descriptions are dropped.
  def node_for(schema, segment = :none)
    path = segment == :none ? nil : @path + [ segment ]
    self.class.new(schema, @entities, @schemas, path ? @notes : {}, path || []).call
  end
end
