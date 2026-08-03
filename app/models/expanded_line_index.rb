class ExpandedLineIndex
  def initialize(lines, entities)
    @lines = lines.lines
    @entities = entities.index_by(&:name)
  end

  def to_a
    index = 0
    @lines.map do |line|
      next nil if line.change == :blank

      current = index
      index += rows_for(line)
      current
    end
  end

  private

  def rows_for(line)
    return 1 unless line.class_name == "custom"

    expansion = @entities.fetch(line.type).to_lines
    expansion.length + (line.pre_type.present? && expansion.first.is_opening ? 1 : 0)
  end
end
