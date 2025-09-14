class TestServerController < ApplicationController
  skip_before_action :verify_authenticity_token
  allow_unauthenticated_access

  class InvalidResponseCode < StandardError; end

  def version
    project = Project.find_by!(name: request.params[:project_name])
    version = Version.find_by!(project: project, name: request.params[:version_name])
    # authorize
    endpoint = Endpoint.from_version_request(request, version).first
    render json: output(endpoint, request).to_example_json
  end

  def candidate
    project = Project.find_by!(name: request.params[:project_name])
    candidate = Candidate.find_by!(name: request.params[:candidate_name], project: project)
    # authorize
    version = candidate.latest_version
    endpoint = Endpoint.from_candidate_request(request, version).first
    render json: output(endpoint, request).to_example_json
  end

  def output(endpoint, request)
    desired_response = request.params[:response]
    return endpoint.parsed_output if desired_response.nil?

    response = endpoint.responses.where(code: desired_response)
    raise InvalidResponseCode.new("Invalid response code: #{desired_response}") if response.empty?

    return endpoint.parsed_output if desired_response.start_with?("2")
    endpoint.parsed_output_error
  end
end
