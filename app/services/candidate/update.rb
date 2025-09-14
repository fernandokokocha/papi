class Candidate::Update
  attr_reader :params, :candidate, :version

  def initialize(candidate, params)
    @candidate = candidate
    @params = params
  end

  def call
    ActiveRecord::Base.transaction do
      @version = @candidate.versions.last
      @version.endpoints.destroy_all
      @version.entities.destroy_all

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

      raise ActiveRecord::RecordInvalid unless @version.update(params[:version])
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
