class ProjectsController < ApplicationController
  def index
    @group = Current.user.group
    @projects = Project.where(group: @group).sort_by(&:name)
  end

  def new
    @project = Project.new(group: Current.user.group)
  end

  def create
    params.permit!
    @project = Project.new(params[:project])
    authorize @project

    if @project.save
      redirect_to projects_path
    else
      render :new, status: :unprocessable_entity
    end
  end
end
