# The endpoints submit themselves with every op, so an edit anywhere on the page
# is answered with the verbs, paths, params, auth and notes the form is holding.
class SchemaForm::Endpoints
  include Enumerable

  def self.from(submitted)
    new((submitted || {}).each_pair.map do |_position, attributes|
      SchemaForm::Endpoint.new(
        http_verb: attributes[:http_verb], path: attributes[:path],
        auth: attributes[:auth].to_s, note: attributes[:note].to_s,
        param_kinds: (attributes[:params] || {}).each_pair.to_h,
        query_params: (attributes[:query_params] || {}).each_pair.map do |_index, query_param|
          SchemaForm::QueryParam.new(name: query_param[:name], kind: query_param[:kind],
                                     required: query_param[:required].present?)
        end,
        responses: (attributes[:responses] || {}).each_pair.map do |code, response|
          SchemaForm::Response.new(code: code, note: response[:note].to_s)
        end.sort_by(&:code)
      )
    end)
  end

  def self.for_version(endpoints)
    new(endpoints.map do |endpoint|
      SchemaForm::Endpoint.new(
        http_verb: endpoint.http_verb, path: endpoint.path,
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

  def adding_query_param(position)
    at(position, &:adding_query_param)
  end

  def dropping_query_param(position, index)
    at(position) { |endpoint| endpoint.dropping_query_param(index) }
  end

  def toggling_query_param(position, index)
    at(position) { |endpoint| endpoint.toggling_query_param(index) }
  end

  def adding_response(position, code)
    at(position) { |endpoint| endpoint.adding_response(code) }
  end

  def dropping_response(position, code)
    at(position) { |endpoint| endpoint.dropping_response(code) }
  end

  private

  def at(position)
    self.class.new(@endpoints.map.with_index { |endpoint, index| index == position ? yield(endpoint) : endpoint })
  end
end
