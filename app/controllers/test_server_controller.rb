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

    if desired_response.nil?
      response = default_response(endpoint)
      raise InvalidResponseCode.new("No responses defined") if response.nil?
      return response.parsed_output
    end

    response = endpoint.responses.find_by(code: desired_response)
    raise InvalidResponseCode.new("Invalid response code: #{desired_response}") if response.nil?
    response.parsed_output
  end

  def default_response(endpoint)
    responses = endpoint.responses.sort_by(&:code)
    responses.find { |r| r.code.start_with?("2") } || responses.first
  end
end
