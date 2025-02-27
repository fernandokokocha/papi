class PrimitiveNode < ApplicationRecord
  enum :kind, [ :string, :number ]

  def print(t)
    kind.to_s
  end
end
