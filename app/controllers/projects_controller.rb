class ProjectsController < ApplicationController
  def index
    @group = Current.user.group
    @projects = Project.where(group: @group).sort_by(&:name)
  end
  #
  # def show
  #   @project = Project.find_by(name: params[:project_name])
  # end

  def new
    @project = Project.new(group: Current.user.group)
  end

  def create
    params.permit!
    puts params[:project]
    @project = Project.new(params[:project])

    if @project.save
      redirect_to projects_path
    else
      puts @project.errors.full_messages
      render :new, status: :unprocessable_entity
    end
  end
end
