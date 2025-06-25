class Diff::ObjectToObject
  attr_accessor :before, :after

  def initialize(value1, value2, indent = 0)
    before = Diff::Lines.new([ Diff::Line.new("{", :no_change, indent) ])
    after = Diff::Lines.new([ Diff::Line.new("{", :no_change, indent) ])

    value2.object_attributes.sort_by { |oa| oa.order }.each do |oa|
      matching_attribute = value1.object_attributes.select { |a| a.name == oa.name }
      if matching_attribute.empty?
        other = Node::Nothing.new
      else
        other = matching_attribute.first.value
      end

      subdiff = Diff::FromValues.new(other, oa.value, indent + 1)
      subdiff.add_parent(oa.name)
      before.concat(subdiff.before)
      after.concat(subdiff.after)
    end

    value1.object_attributes.sort_by { |oa| oa.order }.each do |oa|
      matching_attribute = value2.object_attributes.select { |a| a.name == oa.name }
      next if matching_attribute.any?

      subdiff = Diff::FromValues.new(oa.value, Node::Nothing.new, indent + 1)
      subdiff.add_parent(oa.name)

      before.concat(subdiff.before)
      after.concat(subdiff.after)
    end

    before.add_line(Diff::Line.new("}", :no_change, indent))
    after.add_line(Diff::Line.new("}", :no_change, indent))

    @before = before
    @after = after
  end
end
