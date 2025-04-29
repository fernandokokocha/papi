class ObjectNode < ApplicationRecord
  has_many :object_attributes, foreign_key: :parent_id, dependent: :destroy

  def print(t)
    "{\n" + print_content(t) + "\n" + (" " * t) + "}"
  end

  def print_content(t)
    object_attributes.sort_by(&:order).map do |oa|
      "#{oa.print(t + 2)}"
    end.join(",\n")
  end

  def lines(t)
    [ "{",
     *content_lines(t + 2),
     " " * t + "}" ]
  end

  def content_lines(t)
    object_attributes.sort_by(&:order).map { |oa| oa.lines(t) }.flatten
  end

  def ==(other)
    children_match = object_attributes.all? do |attr|
      found = other.object_attributes.where(name: attr.name).first
      found && found.value == attr.value
    end
    (self.class == other.class) && children_match
  end
end
