# The endpoints submit themselves with every op, so an edit anywhere on the page
# is answered with the verbs, paths, params, auth and notes the form is holding.
class SchemaForm::Endpoints
  include Enumerable

  NEW_VERB = "verb_get".freeze

  def self.from(submitted)
    new((submitted || {}).each_pair.map do |key, attributes|
      SchemaForm::Endpoint.new(
        key: key, http_verb: attributes[:http_verb], path: attributes[:path],
        auth: attributes[:auth].to_s, note: attributes[:note].to_s,
        param_kinds: (attributes[:params] || {}).each_pair.to_h,
        query_params: (attributes[:query_params] || {}).each_pair.map do |_index, query_param|
          SchemaForm::QueryParam.new(name: query_param[:name], kind: query_param[:kind],
                                     required: query_param[:required].present?)
        end,
        responses: (attributes[:responses] || {}).each_pair.map do |code, response|
          SchemaForm::Response.new(code: code, note: response[:note].to_s)
        end.sort_by(&:code),
        removed: attributes[:removed].present?, added: attributes[:added].present?
      )
    end)
  end

  def self.for_version(endpoints)
    new(endpoints.each_with_index.map do |endpoint, index|
      SchemaForm::Endpoint.new(
        key: index.to_s, http_verb: endpoint.http_verb, path: endpoint.path,
        auth: endpoint.auth.to_s, note: endpoint.note.to_s,
        param_kinds: endpoint.path_params.to_h { |param| [ param.name, param.kind ] },
        query_params: endpoint.query_params.map do |param|
          SchemaForm::QueryParam.new(name: param.name, kind: param.kind, required: param.required)
        end,
        responses: endpoint.responses.sort_by(&:code).map do |response|
          SchemaForm::Response.new(code: response.code, note: response.note)
        end
      )
    end)
  end

  def initialize(endpoints)
    @endpoints = endpoints
  end

  def each(&block)
    @endpoints.each(&block)
  end

  def next_key
    (map { |endpoint| endpoint.key.to_i }.max.to_i + 1).to_s
  end

  def adding(key, http_verb, path)
    self.class.new(@endpoints + [
      SchemaForm::Endpoint.new(key: key, http_verb: http_verb, path: path, auth: "", note: "",
                               param_kinds: {}, query_params: [], responses: [], added: true)
    ])
  end

  def dropping(key)
    self.class.new(reject { |endpoint| endpoint.key == key })
  end

  def removing(key)
    at(key) { |endpoint| endpoint.with_removed(true) }
  end

  def restoring(key)
    at(key) { |endpoint| endpoint.with_removed(false) }
  end

  # Adding back what was just removed is a restore: the version cannot hold two
  # endpoints of one identity, so the removed card would otherwise sit above a
  # twin that reads as a change against it.
  def removed_twin(http_verb, path)
    identity = [ http_verb, ::Endpoint.identity_path(path) ]
    find { |endpoint| endpoint.removed && endpoint.identity == identity }
  end

  def new_endpoint_error(http_verb, path)
    return "An endpoint needs a path" if path.blank?
    return "This endpoint already exists" if reject(&:removed).any? { |endpoint|
      endpoint.identity == [ http_verb, ::Endpoint.identity_path(path) ]
    }

    nil
  end

  def adding_query_param(key)
    at(key, &:adding_query_param)
  end

  def dropping_query_param(key, index)
    at(key) { |endpoint| endpoint.dropping_query_param(index) }
  end

  def toggling_query_param(key, index)
    at(key) { |endpoint| endpoint.toggling_query_param(index) }
  end

  def adding_response(key, code)
    at(key) { |endpoint| endpoint.adding_response(code) }
  end

  def dropping_response(key, code)
    at(key) { |endpoint| endpoint.dropping_response(code) }
  end

  private

  def at(key)
    self.class.new(map { |endpoint| endpoint.key == key ? yield(endpoint) : endpoint })
  end
end
