class CandidatesController < ApplicationController
  def show
    @project = Project.find_by!(name: params[:project_name])
    @candidate = Candidate.find_by!(name: params[:name], project: @project)
    authorize @candidate
    @version = @candidate.latest_version
    @previous_version = @project.latest_version

    @categorized_endpoints = Version::CategorizeByName.new(@previous_version.endpoints, @version.endpoints).call
    @categorized_entities = Version::CategorizeByName.new(@previous_version.entities, @version.entities).call

    render "versions/show"
  end

  def new
    @project = Project.find_by!(name: params[:project_name])
    @latest_candidate = @project.latest_candidate
    @candidate = Candidate.new
    @candidate.project = @latest_candidate.project
    @candidate.order = @latest_candidate.order + 1
    @candidate.name = "rc#{@candidate.order}"
    @candidate.created_at = Time.zone.now
    @candidate.updated_at = Time.zone.now
    authorize @candidate

    @latest_version = @project.latest_version
    @version = @latest_version.amoeba_dup
    @version.order = 1
    @version.name = "#{@candidate.name}-v#{@version.order}"
    @version.created_at = Time.zone.now
    @version.updated_at = Time.zone.now
    @version.candidate = @candidate
  end

  def create
    params.permit!
    candidate = Candidate.new(params[:candidate])
    authorize candidate
    service = Candidate::Create.new(params)
    service.call

    redirect_to project_candidate_path(name: service.candidate.name, project_name: service.candidate.project.name)
  rescue ActiveRecord::RecordInvalid => e
    # puts service.candidate.errors.full_messages
    redirect_to new_project_candidate_path(project_name: candidate.project.name)
  end
end
