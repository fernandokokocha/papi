class DiffLine
  attr_accessor :line, :change, :indent

  def initialize(line, change, indent)
    @line = line
    @change = change
    @indent = indent
  end

  def line_with_span_if_primitive
    words = line.split(" ")
    return line unless words[1]
    is_primitive = %w[number string boolean].include?(words[1])
    return line unless is_primitive
    ((" " * indent) + words[0] + ' <span class="' + words[1] + '">' + words[1] + "</span>").html_safe
  end

  def ==(other)
    self.class == other.class &&
      @line == other.line &&
      @change == other.change &&
      @indent == other.indent
  end
end
