class ProjectsController < ApplicationController
  def index
    @projects = Project.all.sort_by(&:name)
  end

  def show
    @project = Project.find_by(name: params[:project_name])
  end
end
