class ArrayNode < ApplicationRecord
  belongs_to :value, polymorphic: true

  def to_example_json
    inside = %W[#{value.to_example_json} #{value.to_example_json} #{value.to_example_json}]
    "[ #{inside.join(", ")} ]"
  end

  def to_diff(change, indent = 0)
    ret = Diff::Lines.new([ Diff::Line.new("[", change, indent) ])
    ret.concat(value.to_diff(change, indent + 1))
    ret.concat([ Diff::Line.new("]", change, indent) ])
    ret
  end

  def serialize
    "[ #{value.serialize} ]"
  end

  def ==(other)
    (self.class == other.class) && self.value == other.value
  end
end
