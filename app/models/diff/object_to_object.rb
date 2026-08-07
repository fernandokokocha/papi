class Diff::ObjectToObject
  attr_accessor :before, :after

  def initialize(value1, value2, indent = 0)
    before = Diff::Lines.new([ Diff::Line.new("{", :no_change, indent) ])
    after = Diff::Lines.new([ Diff::Line.new("{", :no_change, indent) ])

    value2.object_attributes.each do |oa|
      matching = value1.object_attributes.find { |a| a.name == oa.name }

      subdiff = Diff::FromValues.new(matching ? matching.value : Node::Nothing.new, oa.value, indent + 1)
      subdiff.add_parent(matching ? matching.label : oa.label, oa.label)
      subdiff.mark_parents(:type_changed) if matching && matching.optional != oa.optional

      before.concat(subdiff.before)
      after.concat(subdiff.after)
    end

    value1.object_attributes.each do |oa|
      next if value2.object_attributes.any? { |a| a.name == oa.name }

      subdiff = Diff::FromValues.new(oa.value, Node::Nothing.new, indent + 1)
      subdiff.add_parent(oa.label, oa.label)

      before.concat(subdiff.before)
      after.concat(subdiff.after)
    end

    before.add_line(Diff::Line.new("}", :no_change, indent))
    after.add_line(Diff::Line.new("}", :no_change, indent))

    @before = before
    @after = after
  end
end
