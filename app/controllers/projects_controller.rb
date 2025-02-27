class ProjectsController < ApplicationController
  def index
    @projects = Project.all.sort_by(&:name)
  end

  def show
    @project = Project.find(params[:id])
  end
end
