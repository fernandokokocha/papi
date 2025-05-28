class Diff::FromValues
  attr_accessor :before, :after

  def initialize(value1, value2, indent = 0)
    class_to_call = "Diff::#{value1.class.name}To#{value2.class.name}".constantize
    diff = class_to_call.new(value1, value2, indent)

    @before = diff.before
    @after = diff.after
  end

  def add_parent(name)
    @before.add_parent(name)
    @after.add_parent(name)
  end

  def print
    puts "BEFORE:"
    @before.print
    puts "AFTER:"
    @after.print
  end
end
