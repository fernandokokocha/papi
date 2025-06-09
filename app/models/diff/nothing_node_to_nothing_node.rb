class Diff::NothingNodeToNothingNode
  attr_accessor :before, :after

  def initialize(value1, value2, indent = 0)
    @before = Diff::Lines.new([])
    @after = Diff::Lines.new([])
  end
end
