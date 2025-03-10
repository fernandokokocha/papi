class DiffLine
  attr_accessor :line, :change

  def initialize(line, change)
    @line = line
    @change = change
  end

  def ==(other)
    self.class == other.class &&
      @line == other.line &&
      @change == other.change
  end
end
