class Diff
  attr_accessor :endpoint1, :endpoint2, :before, :after

  def initialize(endpoint1, endpoint2)
    @endpoint1 = endpoint1
    @endpoint2 = endpoint2

    if @endpoint1
      @before, @after = diff_objects(@endpoint1.endpoint_root, @endpoint2.endpoint_root, 0)
    else
      @before, @after = diff_nil(@endpoint2.endpoint_root, 0)
    end
  end

  def diff_objects(object1, object2, t, parent_name = "")
    first_line = " " * t
    unless parent_name.empty?
      first_line += parent_name + ": "
    end
    first_line += "{"
    before = [
      DiffLine.new(first_line, :no_change)
    ]
    after = [
      DiffLine.new(first_line, :no_change)
    ]

    object2.object_attributes.sort_by { |oa| oa.order }.each do |oa|
      o1_attrs = object1.object_attributes.where(name: oa.name).limit(1)
      if o1_attrs.empty?
        before << DiffLine.new("", :blank)
        after << DiffLine.new(oa.lines(t + 2), :added)
      else
        value = o1_attrs[0].value
        if value.kind_of?(ObjectNode)
          child_diff = diff_objects(o1_attrs[0].value, oa.value, t + 2, oa.name)
          child_diff_before = child_diff[0].each_with_index.map do |diff, i|
            DiffLine.new(" " * t + diff.line, diff.change)
          end
          before = before + child_diff_before

          child_diff_after = child_diff[1].each_with_index.map do |diff, i|
            DiffLine.new(" " * t + diff.line, diff.change)
          end
          after = after + child_diff_after
        elsif value.kind == oa.value.kind
          before << DiffLine.new(oa.lines(t + 2), :no_change)
          after << DiffLine.new(oa.lines(t + 2), :no_change)
        else
          before << DiffLine.new(o1_attrs[0].lines(t + 2), :type_changed)
          after << DiffLine.new(oa.lines(t + 2), :type_changed)
        end
      end
    end

    object1.object_attributes.sort_by { |oa| oa.order }.each do |oa|
      o2_attrs = object2.object_attributes.where(name: oa.name).limit(1)
      if o2_attrs.empty?
        before << DiffLine.new(oa.lines(t + 2), :removed)
        after << DiffLine.new("", :blank)
      else
        #
      end
    end

    before << DiffLine.new(" " * t + "}", :no_change)
    after << DiffLine.new(" " * t + "}", :no_change)

    [ before, after ]
  end

  def diff_nil(object, t, parent_name = "")
    first_line = " " * t
    unless parent_name.empty?
      first_line += parent_name + ": "
    end
    first_line += "{"
    before = [
      DiffLine.new("", :blank)
    ]
    after = [
      DiffLine.new(first_line, :added)
    ]

    object.object_attributes.sort_by { |oa| oa.order }.each do |oa|
      value = oa.value
      if value.kind_of?(ObjectNode)
        child_diff = diff_nil(oa.value, t + 2, oa.name)
        child_diff_after = child_diff[1].each_with_index.map do |diff, i|
          before << DiffLine.new("", :blank)
          DiffLine.new(" " * t + diff.line, diff.change)
        end
        after = after + child_diff_after
      else
        before << DiffLine.new("", :blank)
        after << DiffLine.new(oa.lines(t + 2), :added)
      end
    end

    before << DiffLine.new("", :blank)
    after << DiffLine.new(" " * t + "}", :added)

    [ before, after ]
  end
end
