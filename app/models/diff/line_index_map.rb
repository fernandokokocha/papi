# Aligns a rendered (collapsed) after-side row stream against its expanded
# twin: rows match by text; a collapsed entity reference stands in for the
# expanded subtree that replaces it and maps to that subtree's first row.
class Diff::LineIndexMap
  CLOSERS = [ "}", "]" ].freeze

  def initialize(rendered_lines, expanded_lines)
    @rendered = rendered_lines.lines
    @expanded = expanded_lines.lines
  end

  # result[rendered_index] = canonical expanded-tree index; nil for blank
  # alignment rows (they are not pickable).
  def to_a
    e = 0
    @rendered.map do |row|
      next nil if row.change == :blank

      e += 1 while @expanded[e] && @expanded[e].change == :blank
      canonical = e
      e = row.whole_line == @expanded[e]&.whole_line ? e + 1 : skip_expansion(e)
      canonical
    end
  end

  private

  # Advance past the expanded subtree standing in for one collapsed entity
  # reference: an optional "name:" label row, then a bracketed block — or a
  # single row when the entity root is a primitive.
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
