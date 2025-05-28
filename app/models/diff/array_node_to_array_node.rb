class Diff::ArrayNodeToArrayNode
  attr_accessor :before, :after

  def initialize(value1, value2, indent = 0)
    before = Diff::Lines.new([ Diff::Line.new("[", :no_change, indent) ])
    after = Diff::Lines.new([ Diff::Line.new("[", :no_change, indent) ])

    subdiff = Diff::FromValues.new(value1.value, value2.value, indent + 1)
    before.concat(subdiff.before)
    after.concat(subdiff.after)

    before.add_line(Diff::Line.new("]", :no_change, indent))
    after.add_line(Diff::Line.new("]", :no_change, indent))

    @before = before
    @after = after
  end
end
