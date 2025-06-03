class PrimitiveNode < ApplicationRecord
  enum :kind, [ :string, :number, :boolean ]

  def to_diff(change, indent = 0)
    Diff::Lines.new([
      Diff::Line.new(kind.to_s, change, indent)
    ])
  end

  def to_example_json
    case kind
    when "string"
      '"abc"'
    when "number"
      "0"
    when "boolean"
      "true"
    end
  end

  def serialize
    kind.to_s
  end

  def ==(other)
    self.class == other.class && kind == other.kind
  end
end
