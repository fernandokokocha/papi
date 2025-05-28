class Diff::Line
  attr_accessor :whole_line, :change, :indent, :is_opening, :pre_type, :type

  def initialize(whole_line, change, indent)
    @whole_line = whole_line
    @change = change
    @indent = indent
    @is_opening = whole_line == "{"

    parse_whole_line
  end

  def add_parent(name)
    @whole_line = name + ": " + @whole_line
    parse_whole_line
  end

  def parse_whole_line
    words = @whole_line.split(":")
    if words.length > 1
      @pre_type = words[0] + ": "
      @type = words[1].strip!
    else
      @pre_type = @whole_line
      @type = nil
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
