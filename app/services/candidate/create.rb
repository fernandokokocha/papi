class Candidate::Create
  attr_reader :params, :candidate, :version

  def initialize(params, author: Current.user)
    @params = params
    @author = author
  end

  # Version's validations are whole-spec questions — endpoints colliding, entity
  # references forming a cycle — so the spec goes in as one nested tree rather
  # than record by record. The candidate has to exist before the version can
  # point at it, and the raise is what takes it back out again when the spec
  # turns out to be invalid.
  def call
    ActiveRecord::Base.transaction do
      assign_candidate_attributes

      @candidate = Candidate.create!(params[:candidate])
      params[:version][:candidate_id] = @candidate.id
      params[:version][:endpoints_attributes] = formatted_endpoints

      @version = Version.new(params[:version])
      raise ActiveRecord::RecordInvalid unless @version.save
    end
  end

  private

  # A project's first candidate has no base version: latest_version answers with
  # a null version, whose id is nil.
  def assign_candidate_attributes
    project = Project.find(params[:candidate][:project_id])
    base_version = project.latest_version
    params[:candidate][:base_version_id] = base_version.id
    params[:candidate][:author_id] = @author.id
    params[:candidate][:decided_by_id] = nil
    params[:candidate][:decided_at] = nil
  end

  def formatted_endpoints
    params[:version][:endpoints_attributes].map do |endpoint_attr|
      {
        path: endpoint_attr[:path],
        http_verb: endpoint_attr[:http_verb],
        note: endpoint_attr[:note],
        input: endpoint_attr[:input],
        auth: endpoint_attr[:auth].to_s,
        version: @version,
        params_attributes: format_params(endpoint_attr[:params]) + format_query_params(endpoint_attr[:query_params]),
        responses_attributes: format_responses(endpoint_attr[:responses])
      }
    end
  end

  def format_params(params_hash)
    return [] unless params_hash
    params_hash.to_hash.entries.map do |name, attrs|
      { name: name, kind: attrs.to_h.with_indifferent_access[:kind].to_s, location: "path", required: true }
    end
  end

  def format_query_params(params_hash)
    return [] unless params_hash
    params_hash.to_hash.entries.map do |name, attrs|
      attrs = attrs.to_h.with_indifferent_access
      { name: name, kind: attrs[:kind].to_s, location: "query", required: attrs[:required] == "true" }
    end
  end

  def format_responses(responses_hash)
    return [] unless responses_hash
    responses_hash.to_hash.entries.map do |code, attrs|
      attrs = attrs.to_h.with_indifferent_access
      { code: code, note: attrs[:note].to_s, output: attrs[:output].to_s }
    end
  end
end
