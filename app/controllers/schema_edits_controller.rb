class SchemaEditsController < ApplicationController
  def create
    case params[:op]
    when "add_entity" then add_entity
    when "drop_entity" then render_entities(blocks.dropping(params[:id]))
    when "remove_entity" then render_entities(blocks.removing(params[:id]))
    when "restore_entity" then render_entities(blocks.restoring(params[:id]))
    when "endpoint" then render_endpoints(endpoints)
    when "add_endpoint" then add_endpoint
    when "drop_endpoint" then render_endpoints(endpoints.dropping(key), blocks.dropping_endpoint(key))
    when "remove_endpoint" then render_endpoints(endpoints.removing(key), blocks.removing_endpoint(key))
    when "restore_endpoint" then render_endpoints(endpoints.restoring(key), blocks.restoring_endpoint(key))
    when "add_query_param" then render_endpoints(endpoints.adding_query_param(key))
    when "drop_query_param" then render_endpoints(endpoints.dropping_query_param(key, query_position))
    when "toggle_query_param" then render_endpoints(endpoints.toggling_query_param(key, query_position))
    when "add_response" then add_response
    when "drop_response" then render_endpoints(endpoints.dropping_response(key, params[:code]))
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

  # The form reads as the diff, so every op has to answer against the version
  # the candidate branched from. It travels as an id in the ops form because it
  # cannot change while the form is open.
  def base_version
    @base_version ||= Version.find_by(id: params[:base_version_id])&.tap { |version| authorize version, :show? } ||
      Version.new
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

  # An endpoint's key outlives its position: dropping one leaves the rest where
  # they were, so the blocks its schemas live in keep the ids they were given.
  def key
    params[:index]
  end

  def query_position
    params[:query].to_i
  end

  def add_entity
    name = params[:new_entity].to_s
    error = blocks.new_entity_error(name)
    twin = blocks.removed_twin(name)

    if error
      render_entities(blocks, new_entity: name, error: error)
    elsif twin
      render_entities(blocks.restoring(twin.id))
    else
      render_entities(blocks.adding(name))
    end
  end

  def add_auth_method
    name = params[:new_auth_method].to_s
    error = auth_methods.new_name_error(name)
    twin = auth_methods.removed_twin_position(name)

    if error
      render_auth_methods(auth_methods, new_auth_method: name, error: error)
    elsif twin
      render_auth_methods(auth_methods.restoring(twin))
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
                           locals: { blocks: edited, base: base_version, new_entity: new_entity, error: error }),
      turbo_stream.replace("entities_nav", partial: "entities/form_nav",
                           locals: { blocks: edited, base: base_version }),
      *endpoints_stream(blocks: edited)
    ]
  end

  def render_auth_methods(edited, new_auth_method: "", error: nil)
    render turbo_stream: [
      turbo_stream.replace("auth_methods", partial: "auth_methods/form_list",
                           locals: { auth_methods: edited, base: base_version,
                                     new_auth_method: new_auth_method, error: error }),
      turbo_stream.replace("auth_methods_nav", partial: "auth_methods/form_nav",
                           locals: { auth_methods: edited, base: base_version }),
      *endpoints_stream(auth_methods: edited)
    ]
  end

  # A response arrives with an output of its own, so the block the editor reads
  # has to be there before the answer is rendered.
  def add_response
    code = params[:new_response][key]

    render turbo_stream: endpoints_stream(endpoints: endpoints.adding_response(key, code),
                                          blocks: blocks.adding_output(key, code))
  end

  # An endpoint arrives with an input of its own, and it is nothing until the
  # editor is asked for something else.
  def add_endpoint
    http_verb = params[:new_endpoint][:http_verb]
    path = params[:new_endpoint][:path].to_s
    error = endpoints.new_endpoint_error(http_verb, path)
    twin = endpoints.removed_twin(http_verb, path)

    if error
      render turbo_stream: endpoints_stream(new_endpoint: { http_verb: http_verb, path: path }, error: error)
    elsif twin
      render_endpoints(endpoints.restoring(twin.key), blocks.restoring_endpoint(twin.key))
    else
      added = endpoints.next_key
      render turbo_stream: endpoints_stream(endpoints: endpoints.adding(added, http_verb, path),
                                            blocks: blocks.adding_endpoint(added))
    end
  end

  def render_endpoints(edited, edited_blocks = blocks)
    render turbo_stream: endpoints_stream(endpoints: edited, blocks: edited_blocks)
  end

  def endpoints_stream(endpoints: self.endpoints, auth_methods: self.auth_methods, blocks: self.blocks,
                       new_endpoint: nil, error: nil)
    [
      turbo_stream.replace("endpoints", partial: "endpoints/form_list",
                           locals: { endpoints: endpoints, auth_methods: auth_methods, blocks: blocks,
                                     base: base_version, new_endpoint: new_endpoint, error: error }),
      turbo_stream.replace("endpoints_nav", partial: "endpoints/form_nav",
                           locals: { endpoints: endpoints, auth_methods: auth_methods, blocks: blocks,
                                     base: base_version })
    ]
  end

  def render_blocks
    block = blocks.fetch(params[:id])
    root = SchemaForm::Operation.new(blocks.parse(block), blocks.version.entities)
      .apply(params[:op], Array(params[:path]), params[:value])

    render_entities(blocks.replacing(block.id, root.serialize))
  end
end
