class SchemaEditsController < ApplicationController
  def create
    case params[:op]
    when "add_entity" then add_entity
    when "drop_entity" then render_entities(blocks.dropping(params[:id]))
    when "remove_entity" then render_entities(blocks.removing(params[:id]))
    when "restore_entity" then render_entities(blocks.restoring(params[:id]))
    when "endpoint" then render_endpoints(endpoints)
    when "add_query_param" then render_endpoints(endpoints.adding_query_param(position))
    when "drop_query_param" then render_endpoints(endpoints.dropping_query_param(position, query_position))
    when "toggle_query_param" then render_endpoints(endpoints.toggling_query_param(position, query_position))
    when "add_response" then add_response
    when "drop_response" then render_endpoints(endpoints.dropping_response(position, params[:code]))
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

  def endpoints
    @endpoints ||= SchemaForm::Endpoints.from(params[:endpoints])
  end

  def position
    params[:index].to_i
  end

  def query_position
    params[:query].to_i
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

  # An entity the form no longer holds is one an input may no longer name, and
  # a new one is a name every input may take from now on, so the endpoints are
  # answered along with the entities. The same holds of the auth methods.
  def render_entities(edited, new_entity: "", error: nil)
    render turbo_stream: [
      turbo_stream.replace("entities", partial: "entities/form_list",
                           locals: { blocks: edited, new_entity: new_entity, error: error }),
      endpoints_stream(blocks: edited)
    ]
  end

  def render_auth_methods(edited, new_auth_method: "", error: nil)
    render turbo_stream: [
      turbo_stream.replace("auth_methods", partial: "auth_methods/form_list",
                           locals: { auth_methods: edited, new_auth_method: new_auth_method, error: error }),
      endpoints_stream(auth_methods: edited)
    ]
  end

  # A response arrives with an output of its own, so the block the editor reads
  # has to be there before the answer is rendered.
  def add_response
    code = params[:new_response][position.to_s]

    render turbo_stream: endpoints_stream(endpoints: endpoints.adding_response(position, code),
                                          blocks: blocks.adding_output(position, code))
  end

  def render_endpoints(edited)
    render turbo_stream: endpoints_stream(endpoints: edited)
  end

  def endpoints_stream(endpoints: self.endpoints, auth_methods: self.auth_methods, blocks: self.blocks)
    turbo_stream.replace("endpoints", partial: "endpoints/form_list",
                         locals: { endpoints: endpoints, auth_methods: auth_methods, blocks: blocks })
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
