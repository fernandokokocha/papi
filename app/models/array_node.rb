class ArrayNode < ApplicationRecord
  belongs_to :value, polymorphic: true

  def to_example_json
    `[ #{value.to_example_json} ]`
  end
end
