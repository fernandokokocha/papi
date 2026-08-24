class SchemaEditsController < ApplicationController
  def create
    submitted = SchemaForm::Blocks.from(params[:blocks])

    case params[:op]
    when "add_entity" then add_entity(submitted)
    when "drop_entity" then render_entities(submitted.dropping(params[:id]))
    when "remove_entity" then render_entities(submitted.removing(params[:id]))
    when "restore_entity" then render_entities(submitted.restoring(params[:id]))
    else render_blocks(submitted)
    end
  end

  private

  def add_entity(submitted)
    name = params[:new_entity].to_s
    error = submitted.new_entity_error(name)

    if error
      render_entities(submitted, new_entity: name, error: error)
    else
      render_entities(submitted.adding(name))
    end
  end

  def render_entities(blocks, new_entity: "", error: nil)
    render turbo_stream: turbo_stream.replace("entities", partial: "entities/form_list",
                                              locals: { blocks: blocks, new_entity: new_entity, error: error })
  end

  def render_blocks(submitted)
    block = submitted.fetch(params[:id])
    root = SchemaForm::Operation.new(submitted.parse(block), submitted.version.entities)
      .apply(params[:op], Array(params[:path]), params[:value])

    edited = submitted.replacing(block.id, root.serialize)

    render turbo_stream: edited.changed_since(submitted).map { |changed|
      turbo_stream.replace(changed.id, partial: "schema_form/editor", locals: edited.locals_for(changed))
    }
  end
end
