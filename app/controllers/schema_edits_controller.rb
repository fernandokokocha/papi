class SchemaEditsController < ApplicationController
  def create
    entities = Array(params[:entity_names]).map { |name| Entity.new(name: name) }
    parsed = JSONSchemaParser.new(entities).parse_value(submitted_schema)
    root = SchemaForm::Operation.new(parsed, entities).apply(params[:op], Array(params[:path]), params[:value])

    render turbo_stream: turbo_stream.replace(params[:id], partial: "schema_form/editor",
      locals: { root: root, id: params[:id], field: params[:field], entity_names: entities.map(&:name) })
  end

  private

  # The whole form comes along, so the block being edited is found by the name
  # of its own hidden field: version[entities_attributes][0][root].
  def submitted_schema
    params.dig(*params[:field].split(/\]\[|\[|\]/).reject(&:empty?))
  end
end
