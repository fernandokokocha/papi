class OpenAPI::ExportSchema
  def initialize(node)
    @node = node
  end

  def call
    case @node
    when Node::Primitive
      { "type" => @node.kind }
    when Node::Object
      object
    when Node::Array
      { "type" => "array", "items" => schema_for(@node.value) }
    when Node::OneOf
      { "oneOf" => @node.branches.map { |branch| schema_for(branch) } }
    when Node::Entity
      { "$ref" => "#/components/schemas/#{@node.entity.name}" }
    else
      raise "#{@node.class} has no JSON Schema equivalent"
    end
  end

  private

  def object
    required = @node.object_attributes.reject(&:optional).map(&:name)

    schema = {
      "type" => "object",
      "properties" => @node.object_attributes.to_h { |attribute| [ attribute.name, schema_for(attribute.value) ] }
    }
    schema["required"] = required if required.any?
    schema
  end

  def schema_for(node)
    self.class.new(node).call
  end
end
