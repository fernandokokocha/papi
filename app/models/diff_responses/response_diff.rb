class DiffResponses::ResponseDiff
  attr_reader :code, :state, :note_diff, :output_diff,
              :before_output, :after_output, :before_note, :after_note

  def initialize(code:, state:, note_diff:, output_diff:, before_present:, after_present:,
                 before_output:, after_output:, before_note:, after_note:)
    @code = code
    @state = state
    @note_diff = note_diff
    @output_diff = output_diff
    @before_present = before_present
    @after_present = after_present
    @before_output = before_output
    @after_output = after_output
    @before_note = before_note
    @after_note = after_note
  end

  def before_present? = @before_present
  def after_present? = @after_present
end
