class CandidatesController < ApplicationController
  def show
    @project = Project.find_by!(name: params[:project_name])
    @candidate = Candidate.find_by!(name: params[:name], project: @project)
    authorize @candidate
    @version = @candidate.latest_version
    @previous_version = @candidate.base_version || Version.null_version(@project)

    @categorized_endpoints = Version::CategorizeByName.new(@previous_version.endpoints, @version.endpoints).call
    @categorized_entities = Version::CategorizeByName.new(@previous_version.entities, @version.entities).call
  end

  def new
    @project = Project.find_by!(name: params[:project_name])
    @latest_candidate = @project.latest_candidate
    @candidate = Candidate.new
    @candidate.project = @latest_candidate.project
    authorize @candidate

    @candidate.order = @latest_candidate.order + 1
    @candidate.name = "rc#{@candidate.order}"
    @candidate.created_at = Time.zone.now
    @candidate.updated_at = Time.zone.now
    @candidate.base_version = @project.latest_version

    @version = @candidate.base_version.amoeba_dup
    @version.order = 1
    @version.name = "#{@candidate.name}-v#{@version.order}"
    @version.created_at = Time.zone.now
    @version.updated_at = Time.zone.now
    @version.candidate = @candidate
  end

  def create
    params.permit!
    @project = Project.find_by!(name: params[:project_name])
    candidate = Candidate.new(params[:candidate])
    candidate.project = @project
    authorize candidate
    service = Candidate::Create.new(params)
    service.call

    redirect_to project_candidate_path(name: service.candidate.name, project_name: service.candidate.project.name)
  rescue ActiveRecord::RecordInvalid => e
    redirect_to new_project_candidate_path(project_name: candidate.project.name)
  end

  def edit
    @project = Project.find_by!(name: params[:project_name])
    @candidate = Candidate.find_by!(name: params[:name], project: @project)
    authorize @candidate

    @version = @candidate.latest_version
  end

  def update
    # Note we find project and candidate by id, unlike in #edit action as we should.
    # This is because form_with model helper (used in version/_form partial) wrongly only sends ids
    # and the params threat it as names (as per routes.rb)
    @project = Project.find(params[:project_name])
    @candidate = Candidate.find_by!(params[:name], project: @project)
    authorize @candidate

    Candidate::Update.new(@candidate, params).call
  end
end
