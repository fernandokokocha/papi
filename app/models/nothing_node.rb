class NothingNode < ApplicationRecord
  def to_diff(change, indent = 0)
    Diff::Lines.new([])
  end

  def to_example_json
    "<empty>"
  end

  def serialize
    "<empty>"
  end

  def ==(other)
    self.class == other.class
  end
end
