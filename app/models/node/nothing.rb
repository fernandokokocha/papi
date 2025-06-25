class Node::Nothing < ApplicationRecord
  self.table_name = "nothing_nodes"

  def to_diff(change, indent = 0)
    Diff::Lines.new([])
  end

  def to_example_json
    ""
  end

  def serialize
    ""
  end

  def ==(other)
    self.class == other.class
  end

  def expand
    self
  end

  def expandable?
    false
  end
end
