class TestServerController < ApplicationController
  skip_before_action :verify_authenticity_token
  allow_unauthenticated_access

  def version
    project = Project.find_by!(name: request.params[:project_name])
    version = Version.find_by!(project: project, name: request.params[:version_name])
    # authorize
    endpoint = Endpoint.from_version_request(request, version).first
    output = endpoint.parsed_output.to_example_json

    render json: output
  end

  def candidate
    project = Project.find_by!(name: request.params[:project_name])
    candidate = Candidate.find_by!(name: request.params[:candidate_name], project: project)
    # authorize
    version = candidate.latest_version
    endpoint = Endpoint.from_candidate_request(request, version).first
    output = endpoint.parsed_output.to_example_json

    render json: output
  end
end
