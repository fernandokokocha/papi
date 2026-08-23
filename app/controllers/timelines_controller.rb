class TimelinesController < ApplicationController
  def show
    @project = Project.find_by!(name: params[:project_name])
    @kind = params[:kind]
    @candidate_name = params[:candidate]

    events = @project.events
    @kind_counts = tally(by_candidate(events), &:verb)
    @candidate_counts = tally(by_kind(events)) { |event| event.candidate.name }
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

  def tally(events, &key)
    events.group_by(&key).transform_values(&:size)
  end
end
