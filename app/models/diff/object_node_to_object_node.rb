class Diff::ObjectNodeToObjectNode
  attr_accessor :before, :after

  def initialize(value1, value2, indent = 0)
    before = Diff::Lines.new([ Diff::Line.new("{", :no_change, indent) ])
    after = Diff::Lines.new([ Diff::Line.new("{", :no_change, indent) ])

    value2.object_attributes.order(:order).each do |oa|
      matching_attribute = value1.object_attributes.where(name: oa.name).limit(1)
      if matching_attribute.empty?
        before.add_line(Diff::Line.new("", :blank, 0))
        subdiff = oa.value.to_diff(:added, indent + 1)
        subdiff.add_parent(oa.name)
        after.concat(subdiff)
      else
        other = matching_attribute.first

        subdiff = Diff::FromValues.new(other.value, oa.value, indent + 1)
        subdiff.add_parent(oa.name)
        before.concat(subdiff.before)
        after.concat(subdiff.after)
      end
    end

    value1.object_attributes.order(:order).each do |oa|
      matching_attribute = value2.object_attributes.where(name: oa.name).limit(1)
      next if matching_attribute.present?

      subdiff = oa.value.to_diff(:removed, indent + 1)
      subdiff.add_parent(oa.name)
      before.concat(subdiff)

      after.add_line(Diff::Line.new("", :blank, 0))
    end

    before.add_line(Diff::Line.new("}", :no_change, indent))
    after.add_line(Diff::Line.new("}", :no_change, indent))

    @before = before
    @after = after
  end
end
