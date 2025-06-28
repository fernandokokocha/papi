class DiffNotes::FromNotes
  attr_accessor :before, :after

  def initialize(note1, note2)
    lines1 = (note1 || "").split("\n")
    lines2 = (note2 || "").split("\n")

    @before = []
    @after = []

    lines2.each do |line|
      if lines1.include?(line)
        @before << DiffNotes::Line.no_change(line)
        @after << DiffNotes::Line.no_change(line)
      else
        @before << DiffNotes::Line.blank
        @after << DiffNotes::Line.added(line)
      end
    end

    lines1.each do |line|
      unless lines2.include?(line)
        @before << DiffNotes::Line.removed(line)
        @after << DiffNotes::Line.blank
      end
    end
  end
end
