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

  def diff_objects(object1, object2, indent, parent_name = "")
    before = []
    after = []

    # Add opening lines
    if parent_name.length > 0
      line = (" " * indent) + parent_name + ":"
      before << DiffLine.new(line, :no_change, indent)
      after << DiffLine.new(line, :no_change, indent)
    end
    line = (" " * indent) + "{"
    before << DiffLine.new(line, :no_change, indent)
    after << DiffLine.new(line, :no_change, indent)

    # Process additions and changes
    process_added_and_changed_attributes(object1, object2, indent, before, after)

    # Process removals
    process_removed_attributes(object1, object2, indent, before, after)

    # Add closing line
    closing_line = " " * indent + "}"
    before << DiffLine.new(closing_line, :no_change, indent)
    after << DiffLine.new(closing_line, :no_change, indent)

    [ before, after ]
  end

  def diff_nil(object, indent, parent_name = "")
    before = []
    after = []

    # Add opening lines
    if parent_name.length > 0
      line = (" " * indent) + parent_name + ":"
      before << DiffLine.new("", :blank, indent)
      after << DiffLine.new(line, :added, indent)
    end
    line = (" " * indent) + "{"
    before << DiffLine.new("", :blank, indent)
    after << DiffLine.new(line, :added, indent)

    # Process all attributes as added
    object.object_attributes.sort_by { |oa| oa.order }.each do |attribute|
      if attribute.value.kind_of?(ObjectNode)
        process_added_object_node(attribute, indent, before, after)
      else
        before << DiffLine.new("", :blank, 0)
        after << DiffLine.new(attribute.lines(indent + 2), :added, indent + 2)
      end
    end

    # Add closing line
    before << DiffLine.new("", :blank, 0)
    after << DiffLine.new(" " * indent + "}", :added, indent)

    [ before, after ]
  end

  private

  def process_added_and_changed_attributes(object1, object2, indent, before, after)
    object2.object_attributes.sort_by { |oa| oa.order }.each do |attribute|
      matching_attributes = object1.object_attributes.where(name: attribute.name).limit(1)

      if matching_attributes.empty?
        add_attribute_as_added(attribute, indent, before, after)
      else
        compare_attribute_values(matching_attributes[0], attribute, indent, before, after)
      end
    end
  end

  def process_removed_attributes(object1, object2, indent, before, after)
    object1.object_attributes.sort_by { |oa| oa.order }.each do |attribute|
      matching_attributes = object2.object_attributes.where(name: attribute.name).limit(1)

      if matching_attributes.empty?
        lines = attribute.lines(indent + 2)

        if lines.kind_of?(Array)
          lines.each do |line|
            line_indent = line.match(/^(\s*)/)[1].length
            before << DiffLine.new(line, :removed, line_indent)
            after << DiffLine.new("", :blank, 0)
          end
        else
          lines_indent = indent + 2
          before << DiffLine.new(lines, :removed, lines_indent)
          after << DiffLine.new("", :blank, 0)
        end
      end
    end
  end

  def add_attribute_as_added(attribute, indent, before, after)
    lines = attribute.lines(indent + 2)

    if lines.kind_of?(Array)
      lines.each do |line|
        line_indent = line.match(/^(\s*)/)[1].length
        before << DiffLine.new("", :blank, 0)
        after << DiffLine.new(line, :added, line_indent)
      end
    else
      lines_indent = indent + 2
      before << DiffLine.new("", :blank, 0)
      after << DiffLine.new(lines, :added, lines_indent)
    end
  end

  def compare_attribute_values(original_attribute, new_attribute, indent, before, after)
    original_value = original_attribute.value
    new_value = new_attribute.value

    if original_value.kind_of?(ObjectNode) && new_value.kind_of?(ObjectNode)
      process_nested_objects(original_value, new_value, indent, new_attribute.name, before, after)
    elsif original_value.kind_of?(ObjectNode)
      process_object_changed_to_primitive(original_attribute, new_attribute, indent, before, after)
    elsif new_value.kind_of?(ObjectNode)
      process_primitive_changed_to_object(original_attribute, new_attribute, indent, before, after)
    elsif original_value.kind == new_value.kind
      before << DiffLine.new(new_attribute.lines(indent + 2), :no_change, indent + 2)
      after << DiffLine.new(new_attribute.lines(indent + 2), :no_change, indent + 2)
    else
      before << DiffLine.new(original_attribute.lines(indent + 2), :type_changed, indent + 2)
      after << DiffLine.new(new_attribute.lines(indent + 2), :type_changed, indent + 2)
    end
  end

  def process_nested_objects(original_value, new_value, indent, attribute_name, before, after)
    child_diff = diff_objects(original_value, new_value, indent + 2, attribute_name)

    child_diff_before = child_diff[0].each_with_index.map do |diff, _|
      DiffLine.new(diff.line, diff.change, diff.indent)
    end
    before.concat(child_diff_before)

    child_diff_after = child_diff[1].each_with_index.map do |diff, _|
      DiffLine.new(diff.line, diff.change, diff.indent)
    end
    after.concat(child_diff_after)
  end

  def process_added_object_node(attribute, indent, before, after)
    child_diff = diff_nil(attribute.value, indent + 2, attribute.name)
    child_diff_after = child_diff[1].each_with_index.map do |diff, i|
      before << DiffLine.new("", :blank, 0)
      DiffLine.new(diff.line, diff.change, diff.indent)
    end
    after.concat(child_diff_after)
  end

  def process_object_changed_to_primitive(original_attribute, new_attribute, indent, before, after)
    child_diff = diff_nil(original_attribute.value, indent + 2, original_attribute.name)
    child_diff_before = child_diff[1].each_with_index.map do |diff, i|
      after_diff_line = i == 0 ? (" " * (indent + 2)) + "#{new_attribute.name}: #{new_attribute.value.kind}" : ""
      after_indent = i == 0 ? indent + 2 : 0
      after << DiffLine.new(after_diff_line, :type_changed, after_indent)
      DiffLine.new(diff.line, :type_changed, diff.indent)
    end
    before.concat(child_diff_before)
  end

  def process_primitive_changed_to_object(original_attribute, new_attribute, indent, before, after)
    child_diff = diff_nil(new_attribute.value, indent + 2, new_attribute.name)
    child_diff_after = child_diff[1].each_with_index.map do |diff, i|
      before_diff_line = i == 0 ? (" " * (indent + 2)) + "#{original_attribute.name}: #{original_attribute.value.kind}" : ""
      before_indent = i == 0 ? indent + 2 : 0
      before << DiffLine.new(before_diff_line, :type_changed, before_indent)
      DiffLine.new(diff.line, :type_changed, diff.indent)
    end
    after.concat(child_diff_after)
  end
end
