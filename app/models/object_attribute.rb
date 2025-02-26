class ObjectAttribute < ApplicationRecord
  belongs_to :parent, class_name: "ObjectNode"
  belongs_to :value, polymorphic: true

  def print
    "#{name}: #{value.print}"
  end
end
