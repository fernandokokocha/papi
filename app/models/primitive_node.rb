class PrimitiveNode < ApplicationRecord
  enum :kind, [ :string, :number ]

  def print(t)
    kind.to_s
  end

  def print_table(t)
    kind.to_s.html_safe
  end

  def lines(t)
    kind.to_s
  end
end
