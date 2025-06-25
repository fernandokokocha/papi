class Node::ObjectAttribute < ApplicationRecord
  belongs_to :parent, class_name: "Node::Object"
  belongs_to :value, polymorphic: true

  def serialize
    name + ": " + value.serialize
  end

  def to_example_json
    '"' + name + '": ' + value.to_example_json
  end

  def expandable?
    true
  end
end
