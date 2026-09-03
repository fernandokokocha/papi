class Diff::FromNotes
  attr_accessor :before, :after

  def initialize(note1, note2)
    lines1 = (note1 || "").split("\n")
    lines2 = (note2 || "").split("\n")

    @before = []
    @after = []

    lines2.each do |line|
      if lines1.include?(line)
        @before << Diff::TextLine.no_change(line)
        @after << Diff::TextLine.no_change(line)
      else
        @before << Diff::TextLine.blank
        @after << Diff::TextLine.added(line)
      end
    end

    lines1.each do |line|
      unless lines2.include?(line)
        @before << Diff::TextLine.removed(line)
        @after << Diff::TextLine.blank
      end
    end
  end

  def any_changes?
    (@before + @after).any? { |line| line.change != :no_change && line.change != :blank }
  end
end
