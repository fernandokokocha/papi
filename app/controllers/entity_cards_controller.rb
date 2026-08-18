class EntityCardsController < ApplicationController
  def show
    @project = Project.find_by!(name: params[:project_name])
    entity = Entity.find(params[:entity_id])
    authorize entity

    entity.annotation = params[:annotation]
    entity.previous = previous_entity(entity)

    render partial: "entities/card_body", layout: false, locals: {
      entity: entity,
      expanded: params[:expanded] == "true",
      base: params[:base],
      project_name: @project.name
    }
  end

  private

  def previous_entity(entity)
    return nil if params[:base].blank? || entity.annotation.in?(%w[added removed])

    base_version = @project.versions.find_by!(name: params[:base])
    base_version.entities.find_by!(name: entity.name)
  end
end
