class Diff::ObjectNodeToEntity
  attr_accessor :before, :after

  def initialize(value1, value2, indent = 0)
    before = Diff::Lines.new([ value1.to_diff(:type_changed, indent) ])
    after = Diff::Lines.new([ value2.to_diff(:type_changed, indent) ])

    after.level_with_blank_lines(before)
    before.level_with_blank_lines(after)

    @before = before
    @after = after
  end
end
