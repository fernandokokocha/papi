# The form reads as the diff, so an endpoint card is answered band by band
# against the endpoint the candidate branched from.
class SchemaForm::EndpointDiff
  ResponseRow = Data.define(:code, :state, :before_response, :before_lines, :note_change)

  def initialize(base, endpoint, blocks, auth_method)
    @base = base
    @endpoint = endpoint
    @blocks = blocks
    @auth_method = auth_method
  end

  def path_params
    @path_params ||= Diff::FromParams.new(@base.path_params, path_param_records)
  end

  def query_params
    @query_params ||= Diff::FromParams.new(@base.query_params, query_param_records)
  end

  def auth
    @auth ||= Diff::FromAuth.new(@base.auth_method, @auth_method)
  end

  def note
    @note ||= Diff::FromNotes.new(@base.note, @endpoint.note)
  end

  def input
    @input ||= Diff::FromValues.new(@base.parsed_input, @blocks.parse(@blocks.input_for(@endpoint.key)))
  end

  def responses
    @responses ||= codes.map { |code| response_row(code) }
  end

  def path_renamed?
    @base.path != @endpoint.path
  end

  def any_changes?
    path_renamed? || path_params.any_changes? || query_params.any_changes? || auth.any_changes? ||
      note.any_changes? || input.any_changes? || input_notes_changed? ||
      responses.any? { |row| row.state != :no_change }
  end

  private

  # A note is spec content, so pinning, rewording or clearing one is a change
  # like any other — and the schema it sits in reads no differently for it.
  def input_notes_changed?
    notes_differ?(@base, @blocks.input_for(@endpoint.key))
  end

  def notes_differ?(record, block)
    SchemaNote.differ?(record.schema_notes, block.notes.map(&:to_record))
  end

  def codes
    (@base.responses.map(&:code) + @endpoint.responses.map(&:code)).uniq.sort
  end

  def response_row(code)
    before = @base.responses.find { |response| response.code == code }
    after = @endpoint.responses.find { |response| response.code == code }

    return ResponseRow.new(code: code, state: :added, before_response: nil, before_lines: nil, note_change: nil) if before.nil?
    return removed_row(code, before) if after.nil?

    block = @blocks.output_for(@endpoint.key, code)
    output = Diff::FromValues.new(before.parsed_output, @blocks.parse(block))
    note_change = before.note == after.note ? "no_change" : "type_changed"
    changed = output.any_changes? || note_change != "no_change" || notes_differ?(before, block)
    ResponseRow.new(code: code, state: changed ? :changed : :no_change, before_response: before,
                    before_lines: output.before, note_change: note_change)
  end

  def removed_row(code, before)
    ResponseRow.new(code: code, state: :removed, before_response: before,
                    before_lines: before.parsed_output.to_diff(:removed), note_change: nil)
  end

  def path_param_records
    @endpoint.path_params.map { |name, kind| EndpointParam.new(name: name, kind: kind, location: "path") }
  end

  def query_param_records
    @endpoint.query_params.map do |param|
      EndpointParam.new(name: param.name, kind: param.kind, required: param.required, location: "query")
    end
  end
end
