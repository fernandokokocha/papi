class Node::ObjectAttribute
  attr_accessor :name, :value

  def initialize(name: "", value: nil)
    @name = name
    @value = value
  end

  def serialize
    name + ":" + value.serialize
  end

  def to_example_json
    '"' + name + '": ' + value.to_example_json
  end

  def expandable?
    true
  end

  def ==(other)
    (self.class == other.class) && (self.name == other.name) && (self.value == other.value)
  end
end
