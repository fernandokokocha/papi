class Diff::OneOfToOneOf
  attr_accessor :before, :after

  def initialize(value1, value2, indent = 0)
    before = Diff::Lines.new([ Diff::Line.new("(", :no_change, indent) ])
    after = Diff::Lines.new([ Diff::Line.new("(", :no_change, indent) ])

    branch_count = [ value1.branches.length, value2.branches.length ].max
    branch_count.times do |position|
      subdiff = Diff::FromValues.new(
        value1.branches[position] || Node::Nothing.new,
        value2.branches[position] || Node::Nothing.new,
        indent + 1
      )
      before.concat(subdiff.before)
      after.concat(subdiff.after)
    end

    before.add_line(Diff::Line.new(")", :no_change, indent))
    after.add_line(Diff::Line.new(")", :no_change, indent))

    @before = before
    @after = after
  end
end
