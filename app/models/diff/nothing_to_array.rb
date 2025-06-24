class Diff::NothingToArray
  attr_accessor :before, :after

  def initialize(value1, value2, indent = 0)
    after = value2.to_diff(:added, indent)
    before = Diff::Lines.new([])
    before.level_with_blank_lines(after)

    @before = before
    @after = after
  end
end
