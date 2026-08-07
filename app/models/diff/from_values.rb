class Diff::FromValues
  attr_accessor :before, :after

  def initialize(value1, value2, indent = 0)
    class_to_call = "Diff::#{value1.class.name.demodulize}To#{value2.class.name.demodulize}".constantize
    diff = class_to_call.new(value1, value2, indent)

    @before = diff.before
    @after = diff.after
  end

  def add_parent(before_name, after_name)
    @before.add_parent(before_name)
    @after.add_parent(after_name)

    @before.level_with_blank_lines(@after)
    @after.level_with_blank_lines(@before)
  end

  def mark_parents(change)
    @before.mark_first(change)
    @after.mark_first(change)
  end

  def any_changes?
    @before.any_changes? || @after.any_changes?
  end

  def print
    puts "BEFORE:"
    @before.print
    puts "AFTER:"
    @after.print
  end
end
