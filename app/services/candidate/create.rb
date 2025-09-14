class Candidate::Create
  attr_reader :params, :candidate, :version

  def initialize(params)
    @params = params
  end

  def call
    ActiveRecord::Base.transaction do
      # STEP 1: assign candidate data
      # (base version only if there is any version in the project)
      project = Project.find(params[:candidate][:project_id])
      base_version = project.latest_version
      params[:candidate][:base_version_id] = base_version.id || nil

      # STEP 2: Create candidate
      @candidate = Candidate.create!(params[:candidate])
      params[:version][:candidate_id] = @candidate.id

      # STEP 3: Map endpoints params - responses should be properly formatted
      params[:version][:endpoints_attributes] = params[:version][:endpoints_attributes].map do |endpoint_attr|
        {
          path: endpoint_attr[:path],
          http_verb: endpoint_attr[:http_verb],
          output: endpoint_attr[:output],
          output_error: endpoint_attr[:output_error],
          note: endpoint_attr[:note],
          version: @version,
          responses_attributes: format_responses(endpoint_attr[:responses])
        }
      end

      # STEP 4: Try and save version
      @version = Version.new(params[:version])
      raise ActiveRecord::RecordInvalid unless @version.save
    end
  end

  private

  def format_responses(responses_hash)
    return [] unless responses_hash
    responses_hash.to_hash.entries.map do |key, value|
      { code: key, note: value }
    end
  end
end
