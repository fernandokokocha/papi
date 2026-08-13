class OpenAPI::ExportSchema
  # A note's path is a property reference already, so it needs no resolving:
  # walking the tree and the path together lands the body on the right schema.
  def initialize(node, notes = {}, path = [])
    @node = node
    @notes = notes
    @path = path
  end

  def call
    described(schema)
  end

  private

  def described(result)
    body = @notes[@path]
    body ? result.merge("description" => body) : result
  end

  def schema
    case @node
    when Node::Primitive
      { "type" => @node.kind }
    when Node::Object
      object
    when Node::Array
      { "type" => "array", "items" => schema_for(@node.value, nil) }
    when Node::OneOf
      { "oneOf" => @node.branches.each_with_index.map { |branch, index| schema_for(branch, index) } }
    when Node::Entity
      { "$ref" => "#/components/schemas/#{@node.entity.name}" }
    else
      raise "#{@node.class} has no JSON Schema equivalent"
    end
  end

  def object
    required = @node.object_attributes.reject(&:optional).map(&:name)

    schema = {
      "type" => "object",
      "properties" => @node.object_attributes.to_h { |attribute| [ attribute.name, schema_for(attribute.value, attribute.name) ] }
    }
    schema["required"] = required if required.any?
    schema
  end

  def schema_for(node, segment)
    self.class.new(node, @notes, @path + [ segment ]).call
  end
end
