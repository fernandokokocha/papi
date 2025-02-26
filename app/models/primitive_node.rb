class PrimitiveNode < ApplicationRecord
  enum :kind, [ :string, :number ]

  def print
    kind.to_s
  end
end
