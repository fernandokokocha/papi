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
      @version.auth_methods.destroy_all

      params[:version][:endpoints_attributes] = params[:version][:endpoints_attributes].map do |endpoint_attr|
        {
          path: endpoint_attr[:path],
          http_verb: endpoint_attr[:http_verb],
          note: endpoint_attr[:note],
          input: endpoint_attr[:input],
          auth: endpoint_attr[:auth].to_s,
          version: @version,
          params_attributes: format_params(endpoint_attr[:params]) + format_query_params(endpoint_attr[:query_params]),
          responses_attributes: format_responses(endpoint_attr[:responses]),
        schema_notes_attributes: format_notes(endpoint_attr[:schema_notes])
        }
      end

      raise ActiveRecord::RecordInvalid unless @version.update(params[:version])
    end
  end

  private

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

  def format_notes(notes_hash)
    return [] unless notes_hash
    notes_hash.to_hash.values.map do |attrs|
      attrs = attrs.to_h.with_indifferent_access
      { path: attrs[:path].to_s, body: attrs[:body].to_s }
    end.reject { |note| note[:body].blank? }
  end

  def format_responses(responses_hash)
    return [] unless responses_hash
    responses_hash.to_hash.entries.map do |code, attrs|
      attrs = attrs.to_h.with_indifferent_access
      { code: code, note: attrs[:note].to_s, output: attrs[:output].to_s,
        schema_notes_attributes: format_notes(attrs[:schema_notes]) }
    end
  end
end
