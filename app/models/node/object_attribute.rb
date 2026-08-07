class Node::ObjectAttribute
  attr_accessor :name, :value, :optional

  def initialize(name: "", value: Node::Nothing.new, optional: false)
    @name = name
    @value = value
    @optional = optional
  end

  def label
    optional ? "#{name}?" : name
  end

  def serialize
    label + ":" + value.serialize
  end

  def to_example_json
    '"' + name + '": ' + value.to_example_json
  end

  def expandable?
    value.expandable?
  end

  def ==(other)
    (self.class == other.class) && (self.name == other.name) &&
      (self.optional == other.optional) && (self.value == other.value)
  end
end
