class Diff::EntityNodeToArrayNode
  attr_accessor :before, :after

  def initialize(value1, value2, indent = 0)
    before = value1.to_diff(:type_changed, indent)
    after = value2.to_diff(:type_changed, indent)

    before.level_with_blank_lines(after)
    after.level_with_blank_lines(before)

    @before = before
    @after = after
  end
end
