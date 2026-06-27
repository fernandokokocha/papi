class DiffResponses::ResponseDiff
  attr_reader :code, :state, :note_diff, :output_diff

  def initialize(code:, state:, note_diff:, output_diff:, before_present:, after_present:)
    @code = code
    @state = state
    @note_diff = note_diff
    @output_diff = output_diff
    @before_present = before_present
    @after_present = after_present
  end

  def before_present? = @before_present
  def after_present? = @after_present
end
