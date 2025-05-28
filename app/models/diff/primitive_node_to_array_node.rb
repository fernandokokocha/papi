class Diff::PrimitiveNodeToArrayNode
  attr_accessor :before, :after

  def initialize(value1, value2, indent = 0)
    after = value2.to_diff(:type_changed, indent)
    before = [ Diff::Line.new("#{value1.kind}", :type_changed, indent) ]
    (after.length - 1).times do
      before << Diff::Line.new("", :blank, 0)
    end

    @before = Diff::Lines.new(before)
    @after = after
  end
end
