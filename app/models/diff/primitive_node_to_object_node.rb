class Diff::PrimitiveNodeToObjectNode
  attr_accessor :before, :after

  def initialize(value1, value2, indent = 0)
    after = value2.to_diff(:type_changed, indent)
    before = Diff::Lines.new([ Diff::Line.new("#{value1.kind}", :type_changed, indent) ])
    before.level_with_blank_lines(after)

    @before = before
    @after = after
  end
end
