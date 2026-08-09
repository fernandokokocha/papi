class EntitiesController < ApplicationController
  def show
    @project = Project.find_by(name: params[:project_name])
    @entity = Entity.find_by(id: params[:id])
    @version = @entity.version

    authorize @entity

    candidate_project = @version.project || @version.candidate&.project
    @candidate = Candidate.find_by(name: params[:candidate], project: candidate_project)

    expanded = params[:expanded].nil? ? true : parse_expanded(params[:expanded])

    case params[:kind]
    when "new"
      render partial: "versions/entity_added", layout: false, locals: { entity: @entity, expanded: expanded }
      return
    when "removed"
      render partial: "versions/entity_removed", layout: false, locals: { entity: @entity, expanded: expanded }
      return
    end

    previous_version = @version.diff_base
    previous_entity = previous_version && previous_version.entities.find_by(name: @entity.name)

    unless previous_entity
      render partial: "versions/entity_added", layout: false, locals: { entity: @entity, expanded: expanded }
      return
    end

    render partial: "versions/entity_diff", layout: false,
           locals: { entity: @entity, previous_entity: previous_entity, expanded: expanded }
  end

  private

  def parse_expanded(expanded)
    expanded != "false"
  end
end
