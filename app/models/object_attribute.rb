class ObjectAttribute < ApplicationRecord
  belongs_to :parent, class_name: "ObjectNode"
  belongs_to :value, polymorphic: true

  def serialize
    name + ": " + value.serialize
  end

  def to_example_json
    '"' + name + '": ' + value.to_example_json
  end
end
