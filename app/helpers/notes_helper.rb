module NotesHelper
  RenderedNote = Struct.new(:body, :was, :state, keyword_init: true)

  def schema_notes_by_row(record, previous_record, lines)
    current = notes_of(record)
    previous = notes_of(previous_record)
    return {} if current.empty? && previous.empty?

    SchemaPathIndex.new(lines).first_row_per_path.filter_map do |path, row|
      next unless current.key?(path) || previous.key?(path)
      [ row, rendered_note(current[path], previous[path], previous_record) ]
    end.to_h
  end

  def schema_note_badge(note)
    return "".html_safe if note.nil?

    tag.span(class: "line-note") do
      safe_join([ tag.span("i", class: "line-note-badge #{note.state}"),
                  tag.span(note_card_content(note), class: "line-note-card line-note-body") ])
    end
  end

  private

  def notes_of(record)
    return {} if record.nil?
    record.schema_notes.to_h { |note| [ note.segments, note.body ] }
  end

  def rendered_note(body, was, previous_record)
    return RenderedNote.new(body: body, state: :no_change) if previous_record.nil?
    return RenderedNote.new(body: was, state: :removed) if body.nil?
    return RenderedNote.new(body: body, state: :added) if was.nil?
    return RenderedNote.new(body: body, state: :no_change) if body == was

    RenderedNote.new(body: body, was: was, state: :changed)
  end

  def note_card_content(note)
    return note.body if note.state == :no_change

    safe_join([ (tag.span(note.was, class: "note-was") if note.was.present?),
                tag.span(note.body, class: "note-now") ].compact)
  end
end
