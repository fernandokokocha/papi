class VersionTestServerConstraint
  def matches?(request)
    project = Project.find_by!(name: request.params[:project_name])
    version = Version.find_by!(project: project, name: request.params[:version_name])
    Endpoint.from_version_request(request, version).present?
  end
end
