class Diff::CollapsedToExpandedMap
  CLOSERS = [ "}", "]" ].freeze

  def initialize(collapsed_lines, expanded_lines)
    @collapsed = collapsed_lines.lines
    @expanded = expanded_lines.lines
  end

  def to_a
    e = 0
    @collapsed.map do |row|
      next nil if row.change == :blank

      e += 1 while @expanded[e] && @expanded[e].change == :blank
      expanded_index = e
      e = row.whole_line == @expanded[e]&.whole_line ? e + 1 : skip_expansion(e)
      expanded_index
    end
  end

  private

  def skip_expansion(e)
    e += 1 if @expanded[e].whole_line.end_with?(":")
    return e + 1 unless @expanded[e]&.is_opening

    depth = 1
    while depth.positive?
      e += 1
      depth += 1 if @expanded[e].is_opening
      depth -= 1 if CLOSERS.include?(@expanded[e].whole_line)
    end
    e + 1
  end
end
