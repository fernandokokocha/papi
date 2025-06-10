class Diff::Lines
  attr_accessor :lines

  delegate :length, :each, :empty?, to: :lines

  def initialize(lines)
    @lines = lines
  end

  def add_parent(name)
    first_line = @lines.first
    if first_line.is_opening
      @lines.unshift(Diff::Line.new("#{name}:", first_line.change, first_line.indent))
    else
      first_line.add_parent(name)
    end
  end

  def concat(array)
    if array.respond_to?(:lines)
      @lines.concat(array.lines)
    else
      @lines.concat(array)
    end
  end

  def add_line(line)
    @lines << line
  end

  def level_with_blank_lines(other)
    (other.length - @lines.length).times do
      @lines << Diff::Line.new("", :blank, 0)
    end
  end

  def print
    @lines.each do |line|
      puts "#{line.indent} #{line.whole_line} (#{line.change})"
    end
  end

  def ==(other)
    self.class == other.class &&
      @lines == other.lines
  end
end
