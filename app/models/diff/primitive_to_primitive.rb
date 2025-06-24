class Diff::PrimitiveToPrimitive
  attr_accessor :before, :after

  def initialize(value1, value2, indent = 0)
    if value1.kind == value2.kind
      before = [ Diff::Line.new(value1.kind, :no_change, indent) ]
      after = [ Diff::Line.new(value2.kind, :no_change, indent) ]
    else
      before = [ Diff::Line.new(value1.kind, :type_changed, indent) ]
      after = [ Diff::Line.new(value2.kind, :type_changed, indent) ]
    end

    @before = Diff::Lines.new(before)
    @after = Diff::Lines.new(after)
  end
end
