class DiffNotes::Line
  attr_accessor :whole_line, :change

  def initialize(whole_line, change)
    @whole_line = whole_line
    @change = change
  end

  def self.blank
    self.new("", :no_change)
  end

  def self.no_change(line)
    self.new(line, :no_change)
  end

  def self.added(line)
    self.new(line, :added)
  end

  def self.removed(line)
    self.new(line, :removed)
  end
end
