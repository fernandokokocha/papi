class EntityHistoriesController < ApplicationController
  def show
    @entity = Entity.find(params[:entity_id])
    authorize @entity
    @project = Project.find_by!(name: params[:project_name])
    @milestones = History.for_entity(@project, @entity).milestones
  end
end
