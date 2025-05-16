class DiffLine
  attr_accessor :line, :change, :indent, :pre_type, :type

  def initialize(line, change, indent)
    @line = line
    @change = change
    @indent = indent

    words = line.split(":")
    if words.length > 1
      @pre_type = words[0] + ": "
      @type = words[1].strip!
    end
  end

  def ==(other)
    self.class == other.class &&
      @line == other.line &&
      @change == other.change &&
      @indent == other.indent
  end
end
