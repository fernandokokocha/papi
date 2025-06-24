class Diff::Line
  attr_accessor :whole_line, :change, :indent, :is_opening, :pre_type, :type, :class_name

  def initialize(whole_line, change, indent)
    @whole_line = whole_line
    @change = change
    @indent = indent
    @is_opening = %w({ [).include?(whole_line)

    infer_type
  end

  def add_parent(name)
    return if @whole_line.empty?
    @whole_line = name + ": " + @whole_line
    infer_type
  end

  def infer_type
    if @whole_line.end_with?("string")
      @type = "string"
      @class_name = "string"
      @pre_type = @whole_line[0..-7]
    elsif @whole_line.end_with?("number")
      @type = "number"
      @class_name = "number"
      @pre_type = @whole_line[0..-7]
    elsif @whole_line.end_with?("boolean")
      @type = "boolean"
      @class_name = "boolean"
      @pre_type = @whole_line[0..-8]
    elsif (custom_name = parse_custom_name(@whole_line))
      @type = custom_name
      @class_name = "custom"
      @pre_type = @whole_line[0..-(custom_name.length + 1)]
    elsif /^[a-zA-Z]+$/ =~ @whole_line
      @type = @whole_line
      @class_name = "custom"
      @pre_type = ""
    else
      @type = nil
      @pre_type = @whole_line
    end
  end

  def parse_custom_name(line)
    /:\s+(.*)$/ =~ line
    $1
  end

  def ==(other)
    self.class == other.class &&
      @whole_line == other.whole_line &&
      @change == other.change &&
      @indent == other.indent
  end
end
