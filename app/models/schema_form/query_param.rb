class SchemaForm::QueryParam
  attr_reader :name, :kind, :required

  def initialize(name:, kind:, required:)
    @name = name
    @kind = kind
    @required = required
  end

  def with_required(required)
    self.class.new(name: name, kind: kind, required: required)
  end
end
