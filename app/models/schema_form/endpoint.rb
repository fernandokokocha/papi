class SchemaForm::Endpoint
  NEW_KIND = "string".freeze
  NEW_QUERY_PARAM = "new".freeze

  attr_reader :key, :http_verb, :path, :auth, :note, :param_kinds, :query_params, :responses, :removed, :added

  def initialize(key:, http_verb:, path:, auth:, note:, param_kinds:, query_params:, responses:,
                 removed: false, added: false)
    @key = key
    @http_verb = http_verb
    @path = path
    @auth = auth
    @note = note
    @param_kinds = param_kinds
    @query_params = query_params
    @responses = responses
    @removed = removed
    @added = added
  end

  def verb
    ::Endpoint::VERB_TRANSLATIONS[http_verb.to_sym]
  end

  def identity
    [ http_verb, ::Endpoint.identity_path(path) ]
  end

  def identity_name
    "#{verb} #{::Endpoint.identity_path(path)}"
  end

  def path_params
    path.scan(::Endpoint::PARAM_TOKEN).flatten.uniq.map { |name| [ name, param_kinds.fetch(name, NEW_KIND) ] }
  end

  def unused_codes
    ::Response::CODES - responses.map(&:code)
  end

  def with_removed(removed)
    with(removed: removed)
  end

  def adding_query_param
    with(query_params: query_params + [ SchemaForm::QueryParam.new(name: unused_query_param_name, kind: NEW_KIND, required: true) ])
  end

  def dropping_query_param(position)
    with(query_params: query_params.reject.with_index { |_query_param, index| index == position })
  end

  def toggling_query_param(position)
    with(query_params: query_params.map.with_index do |query_param, index|
      index == position ? query_param.with_required(!query_param.required) : query_param
    end)
  end

  def adding_response(code)
    with(responses: (responses + [ SchemaForm::Response.new(code: code, note: "") ]).sort_by(&:code))
  end

  def dropping_response(code)
    with(responses: responses.reject { |response| response.code == code })
  end

  private

  def with(**changes)
    self.class.new(**{ key: key, http_verb: http_verb, path: path, auth: auth, note: note, param_kinds: param_kinds,
                       query_params: query_params, responses: responses, removed: removed, added: added }, **changes)
  end

  def unused_query_param_name
    taken = query_params.map(&:name)
    return NEW_QUERY_PARAM unless taken.include?(NEW_QUERY_PARAM)

    (2..).lazy.map { |n| "#{NEW_QUERY_PARAM}#{n}" }.reject { |name| taken.include?(name) }.first
  end
end
