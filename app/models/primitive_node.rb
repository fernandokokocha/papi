class PrimitiveNode < ApplicationRecord
  enum :kind, [ :string, :number, :boolean ]

  def print(t)
    kind.to_s
  end

  def print_table(t)
    kind.to_s.html_safe
  end

  def lines(t)
    kind.to_s
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

  def ==(other)
    self.class == other.class && kind == other.kind
  end
end
