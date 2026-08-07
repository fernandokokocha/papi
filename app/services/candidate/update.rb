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
          note: endpoint_attr[:note],
          input: endpoint_attr[:input],
          version: @version,
          params_attributes: format_params(endpoint_attr[:params]),
          responses_attributes: format_responses(endpoint_attr[:responses])
        }
      end

      raise ActiveRecord::RecordInvalid unless @version.update(params[:version])
    end
  end

  private

  def format_params(params_hash)
    return [] unless params_hash
    params_hash.to_hash.entries.map do |name, attrs|
      { name: name, kind: attrs.to_h.with_indifferent_access[:kind].to_s }
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
