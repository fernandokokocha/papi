class ObjectAttribute < ApplicationRecord
  belongs_to :parent, class_name: "ObjectNode"
  belongs_to :value, polymorphic: true

  def print(t)
    (" " * t) + "#{name}: #{value.print(t)}"
  end

  def lines(t)
    value_lines = value.lines(t)
    if value_lines.is_a?(Array)
      [ " " * t + "#{name}: #{value_lines.shift}" ] + value_lines
    else
      " " * t + "#{name}: #{value_lines}"
    end
  end
end
