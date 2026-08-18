class DiffEndpoint::FromEndpoints
  def initialize(previous, endpoint, expanded: [])
    @previous = previous
    @endpoint = endpoint
    @expanded = expanded
  end

  def path_params
    @path_params ||= DiffParams::FromParams.new(@previous.path_params, @endpoint.path_params)
  end

  def query_params
    @query_params ||= DiffParams::FromParams.new(@previous.query_params, @endpoint.query_params)
  end

  def auth
    @auth ||= DiffAuth::FromAuth.new(@previous.auth_method, @endpoint.auth_method)
  end

  def note
    @note ||= DiffText::FromNotes.new(@previous.note, @endpoint.note)
  end

  def input
    @input ||= Diff::FromValues.new(
      @previous.parsed_input(expanded: input_expanded?),
      @endpoint.parsed_input(expanded: input_expanded?)
    )
  end

  def responses
    @responses ||= DiffResponses::FromResponses.new(@previous.responses, @endpoint.responses, expanded: @expanded)
  end

  def input_expanded?
    @expanded.include?("input")
  end

  def path_renamed?
    @previous.path != @endpoint.path
  end

  def schema_notes_differ?
    SchemaNote.differ?(@previous.schema_notes, @endpoint.schema_notes)
  end

  def any_changes?
    path_renamed? ||
      path_params.any_changes? ||
      query_params.any_changes? ||
      auth.any_changes? ||
      note.any_changes? ||
      schema_notes_differ? ||
      input.any_changes? ||
      responses.any_changes?
  end
end
