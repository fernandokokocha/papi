class DiffResponses::Line
  attr_accessor :code, :code_change, :note, :note_change

  def initialize(code, code_change, note, note_change)
    @code = code
    @code_change = code_change
    @note = note
    @note_change = note_change
  end

  def self.blank
    self.new("", :no_change, "", :no_change)
  end

  def self.no_change(code, note)
    self.new(code, :no_change, note, :no_change)
  end

  def self.note_changed(code, note)
    self.new(code, :no_change, note, :type_changed)
  end

  def self.added(code, note)
    self.new(code, :added, note, :added)
  end

  def self.removed(code, note)
    self.new(code, :removed, note, :removed)
  end
end
