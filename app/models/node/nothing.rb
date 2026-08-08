class Node::Nothing
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

  def entity_names
    []
  end
end
