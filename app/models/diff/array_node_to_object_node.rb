class Diff::ArrayNodeToObjectNode
  attr_accessor :before, :after

  def initialize(value1, value2, indent = 0)
    before = value1.to_diff(:type_changed, indent)
    after = value2.to_diff(:type_changed, indent)

    if before.length < after.length
      before.add_line(Diff::Line.new("", :blank, 0))
    elsif after.length < before.length
      after.add_line(Diff::Line.new("", :blank, 0))
    end

    @before = before
    @after = after
  end
end
