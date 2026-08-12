class TestServerController < ApplicationController
  skip_before_action :verify_authenticity_token
  allow_unauthenticated_access

  class InvalidResponseCode < StandardError; end
  class MissingRequiredParam < StandardError; end

  def version
    project = Project.find_by!(name: request.params[:project_name])
    version = Version.find_by!(project: project, name: request.params[:version_name])
    endpoint = Endpoint.from_version_request(request, version)
    return if refuse_unauthorized(endpoint)

    render json: output(endpoint, request).to_example_json
  end

  def candidate
    project = Project.find_by!(name: request.params[:project_name])
    candidate = Candidate.find_by!(name: request.params[:candidate_name], project: project)
    version = candidate.latest_version
    endpoint = Endpoint.from_candidate_request(request, version)
    return if refuse_unauthorized(endpoint)

    render json: output(endpoint, request).to_example_json
  end

  # A 401 is declared behaviour, not a malformed request, so it is answered
  # rather than raised the way a bad response code or a missing param is.
  def refuse_unauthorized(endpoint)
    auth_method = endpoint.auth_method
    return false if auth_method.nil?
    return false if auth_method.satisfied_by?(request.headers["Authorization"])

    response.headers["WWW-Authenticate"] = auth_method.challenge
    render json: { error: "#{auth_method.name} required" }, status: :unauthorized
    true
  end

  def output(endpoint, request)
    require_query_params(endpoint, request)

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

  # request.params merges in the route's project_name, version_name and glob, so
  # a declared param sharing one of those names would look satisfied.
  def require_query_params(endpoint, request)
    missing = endpoint.query_params.select(&:required).map(&:name) - request.query_parameters.keys
    return if missing.empty?

    raise MissingRequiredParam.new("Missing required query params: #{missing.join(", ")}")
  end

  # When no response code is requested, serve the first response alphabetically
  # by code (for valid 3-digit HTTP codes this is the lowest code).
  def default_response(endpoint)
    endpoint.responses.min_by(&:code)
  end
end
