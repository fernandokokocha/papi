class ProjectsController < ApplicationController
  def index
    @group = Current.user.group
    @projects = Project.where(group: @group).sort_by(&:name)
  end

  def show
    @project = Project.find_by(name: params[:project_name])
  end
end
