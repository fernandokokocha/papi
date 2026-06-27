class DiffResponses::FromResponses
  attr_reader :lines

  def initialize(responses1, responses2, expanded: false)
    @expanded = expanded
    by_code1 = responses1.index_by(&:code)
    by_code2 = responses2.index_by(&:code)
    codes = (by_code1.keys + by_code2.keys).uniq.sort

    @lines = codes.map { |code| build_line(code, by_code1[code], by_code2[code]) }
  end

  def any_changes?
    @lines.any? { |line| line.state != :no_change }
  end

  private

  def build_line(code, before, after)
    note_diff = DiffText::FromNotes.new(before&.note, after&.note)
    output_diff = Diff::FromValues.new(output_value(before), output_value(after))

    state =
      if before.nil?
        :added
      elsif after.nil?
        :removed
      elsif note_diff.any_changes? || output_diff.any_changes?
        :changed
      else
        :no_change
      end

    DiffResponses::ResponseDiff.new(
      code: code, state: state, note_diff: note_diff, output_diff: output_diff,
      before_present: !before.nil?, after_present: !after.nil?
    )
  end

  def output_value(response)
    return Node::Nothing.new if response.nil?
    value = response.parsed_output
    @expanded ? value.expand : value
  end
end
