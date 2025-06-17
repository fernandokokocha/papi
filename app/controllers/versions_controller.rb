class VersionsController < ApplicationController
  include Pundit::Authorization

  def show
    @project = Project.find_by(name: params[:project_name])
    @version = Version.find_by(name: params[:name], project: @project)
    @previous_version = @version.previous
    @next_version = @version.next
  end

  def new
    @project = Project.find_by(name: params[:project_name])
    @latest_version = @project.latest_version
    if @latest_version
      @version = @latest_version.amoeba_dup
      @version.order = @latest_version.order + 1
    else
      @version = Version.new(project: @project)
      @version.order = 1
    end
    @version.name = "v#{@version.order}"
    @version.created_at = Time.now
    @version.updated_at = Time.now
  end

  def create
    params.permit!
    params[:version][:endpoints_attributes].map do |endpoint_attr|
      output = JSONSchemaParser.new.parse_value(endpoint_attr[:original_output_string])
      output.save
      endpoint_attr[:output_id] = output.id
      endpoint_attr[:output_type] = output.class.name

      input = JSONSchemaParser.new.parse_value(endpoint_attr[:original_input_string])
      input.save
      endpoint_attr[:input_id] = input.id
      endpoint_attr[:input_type] = input.class.name
    end
    @version = Version.new(params[:version])

    if @version.save
      redirect_to project_version_path(name: @version.name, project_name: @version.project.name)
    else
      puts @version.errors.full_messages
      render :new, status: :unprocessable_entity
    end
  end

  def index
    @versions = Version.find_by(project: params[:project_id])
  end
end
