class SchemaEditsController < ApplicationController
  def create
    case params[:op]
    when "add_entity" then add_entity
    when "drop_entity" then render_entities(blocks.dropping(params[:id]))
    when "remove_entity" then render_entities(blocks.removing(params[:id]))
    when "restore_entity" then render_entities(blocks.restoring(params[:id]))
    when "auth" then render_auth_methods(auth_methods)
    when "add_auth_method" then add_auth_method
    when "drop_auth_method" then render_auth_methods(auth_methods.dropping(position))
    when "remove_auth_method" then render_auth_methods(auth_methods.removing(position))
    when "restore_auth_method" then render_auth_methods(auth_methods.restoring(position))
    else render_blocks
    end
  end

  private

  def blocks
    @blocks ||= SchemaForm::Blocks.from(params[:blocks])
  end

  def auth_methods
    @auth_methods ||= SchemaForm::AuthMethods.from(params[:auth_methods])
  end

  def position
    params[:index].to_i
  end

  def add_entity
    name = params[:new_entity].to_s
    error = blocks.new_entity_error(name)

    if error
      render_entities(blocks, new_entity: name, error: error)
    else
      render_entities(blocks.adding(name))
    end
  end

  def add_auth_method
    name = params[:new_auth_method].to_s
    error = auth_methods.new_name_error(name)

    if error
      render_auth_methods(auth_methods, new_auth_method: name, error: error)
    else
      render_auth_methods(auth_methods.adding(name))
    end
  end

  def render_entities(edited, new_entity: "", error: nil)
    render turbo_stream: turbo_stream.replace("entities", partial: "entities/form_list",
                                              locals: { blocks: edited, new_entity: new_entity, error: error })
  end

  def render_auth_methods(edited, new_auth_method: "", error: nil)
    render turbo_stream: turbo_stream.replace("auth_methods", partial: "auth_methods/form_list",
                                              locals: { auth_methods: edited, new_auth_method: new_auth_method, error: error })
  end

  def render_blocks
    block = blocks.fetch(params[:id])
    root = SchemaForm::Operation.new(blocks.parse(block), blocks.version.entities)
      .apply(params[:op], Array(params[:path]), params[:value])

    edited = blocks.replacing(block.id, root.serialize)

    render turbo_stream: edited.changed_since(blocks).map { |changed|
      turbo_stream.replace(changed.id, partial: "schema_form/editor", locals: edited.locals_for(changed))
    }
  end
end
