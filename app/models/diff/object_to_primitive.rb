class Diff::ObjectToPrimitive
  attr_accessor :before, :after

  def initialize(value1, value2, indent = 0)
    before = value1.to_diff(:type_changed, indent)
    after = Diff::Lines.new([ Diff::Line.new("#{value2.kind}", :type_changed, indent) ])
    after.level_with_blank_lines(before)

    @before = before
    @after = after
  end
end
