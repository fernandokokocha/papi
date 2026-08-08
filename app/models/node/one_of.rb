class Node::OneOf
  attr_accessor :branches

  def initialize(branches: [])
    @branches = branches
  end

  def to_example_json
    branches.first.to_example_json
  end

  def to_diff(change, indent = 0)
    ret = Diff::Lines.new([ Diff::Line.new("(", change, indent) ])
    branches.each { |branch| ret.concat(branch.to_diff(change, indent + 1)) }
    ret.concat([ Diff::Line.new(")", change, indent) ])
    ret
  end

  def serialize
    "(#{branches.map(&:serialize).join("|")})"
  end

  def ==(other)
    (self.class == other.class) && (branches == other.branches)
  end

  def expand
    Node::OneOf.new(branches: branches.map(&:expand))
  end

  def expandable?
    branches.any?(&:expandable?)
  end

  def entity_names
    branches.flat_map(&:entity_names)
  end
end
