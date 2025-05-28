class Diff::Line
  attr_accessor :whole_line, :change, :indent, :is_opening, :pre_type, :type

  def initialize(whole_line, change, indent)
    @whole_line = whole_line
    @change = change
    @indent = indent
    @is_opening = %w({ [).include?(whole_line)

    infer_type
  end

  def add_parent(name)
    @whole_line = name + ": " + @whole_line
    infer_type
  end

  def infer_type
    if @whole_line.end_with?("string")
      @type = "string"
      @pre_type = @whole_line[0..-7]
    elsif @whole_line.end_with?("number")
      @type = "number"
      @pre_type = @whole_line[0..-7]
    elsif @whole_line.end_with?("boolean")
      @type = "boolean"
      @pre_type = @whole_line[0..-8]
    else
      @type = nil
      @pre_type = @whole_line
    end
  end

  def line(tab = 2)
    formatted_line = @whole_line
    if @type
      formatted_line = "#{@pre_type}<span class=\"#{@type}\">#{@type}</span>"
    end
    ((" " * (@indent * tab)) + formatted_line).html_safe
  end

  def ==(other)
    self.class == other.class &&
      @whole_line == other.whole_line &&
      @change == other.change &&
      @indent == other.indent
  end
end
