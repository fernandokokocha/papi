class CandidateTestServerConstraint
  def matches?(request)
    project = Project.find_by!(name: request.params[:project_name])
    candidate = Candidate.find_by!(name: request.params[:candidate_name], project: project)
    # authorize
    version = candidate.latest_version
    Endpoint.from_candidate_request(request, version).any?
  end
end
