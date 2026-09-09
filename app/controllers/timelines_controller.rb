class TimelinesController < ApplicationController
  KINDS = %i[opened commented approved merged rejected].freeze

  def show
    @project = Project.find_by!(name: params[:project_name])
    authorize @project
    @kind = params[:kind]
    @candidate_name = params[:candidate]

    events = @project.events
    @kind_counts = counts(by_candidate(events), KINDS, &:verb)
    @candidate_counts = counts(by_kind(events), @project.history.map(&:name)) { |event| event.candidate.name }
    @events = by_kind(by_candidate(events))
  end

  private

  def by_kind(events)
    return events if @kind.blank?

    events.select { |event| event.verb.to_s == @kind }
  end

  def by_candidate(events)
    return events if @candidate_name.blank?

    events.select { |event| event.candidate.name == @candidate_name }
  end

  # Zero-filled and in a fixed order, so a facet greys out where it would
  # otherwise vanish and take every facet below it up a line.
  def counts(events, keys, &key)
    tallied = events.group_by(&key).transform_values(&:size)
    keys.index_with { |value| tallied.fetch(value, 0) }
  end
end
