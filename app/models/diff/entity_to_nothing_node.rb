class Diff::EntityToNothingNode
  attr_accessor :before, :after

  def initialize(value1, value2, indent = 0)
    before = value1.to_diff(:added, indent)
    after = Diff::Lines.new([])
    after.level_with_blank_lines(before)

    @before = before
    @after = after
  end
end
