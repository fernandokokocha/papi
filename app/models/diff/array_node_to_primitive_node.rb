class Diff::ArrayNodeToPrimitiveNode
  attr_accessor :before, :after

  def initialize(value1, value2, indent = 0)
    before = value1.to_diff(:type_changed, indent)
    after = [ Diff::Line.new("#{value2.kind}", :type_changed, indent) ]
    (before.length - 1).times do
      after << Diff::Line.new("", :blank, 0)
    end

    @before = before
    @after = Diff::Lines.new(after)
  end
end
