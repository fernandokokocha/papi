class DesignPreviewController < ApplicationController
  allow_unauthenticated_access

  def show
    @diff_endpoints = diff_endpoints
    @unchanged_endpoints = unchanged_endpoints
    @new_endpoint = new_endpoint
    @removed_endpoint = removed_endpoint

    @diff_entities = diff_entities
    @unchanged_entities = unchanged_entities
    @new_entity = new_entity
    @removed_entity = removed_entity
  end

  private

  FakeResponse = Struct.new(:code, :note)
  FakeEndpoint = Struct.new(:name, :verb, :path, :note, :responses, :parsed_output, :parsed_output_error) do
    def differs_from?(previous)
      DiffText::FromNotes.new(previous.note, note).any_changes? ||
        DiffResponses::FromResponses.new(previous.responses, responses).any_changes? ||
        Diff::FromValues.new(previous.parsed_output.expand, parsed_output.expand).any_changes? ||
        Diff::FromValues.new(previous.parsed_output_error.expand, parsed_output_error.expand).any_changes?
    end
  end
  FakeEntity = Struct.new(:name, :parsed_root) do
    def differs_from?(previous)
      Diff::FromValues.new(previous.parsed_root, parsed_root).any_changes?
    end
  end

  def diff_endpoints
    parser = JSONSchemaParser.new([])
    previous = FakeEndpoint.new(
      "GET /users",
      "GET",
      "/users",
      "Returns a list of users.",
      [ FakeResponse.new(200, "Success"), FakeResponse.new(404, "Not found") ],
      parser.parse_value("{id:number,name:string,email:string}"),
      parser.parse_value("{error:string}")
    )
    current = FakeEndpoint.new(
      "GET /users",
      "GET",
      "/users",
      "Returns a paginated list of users.\nUse the page and per_page params to paginate.",
      [ FakeResponse.new(200, "Success"), FakeResponse.new(400, "Bad request"), FakeResponse.new(404, "Not found") ],
      parser.parse_value("{id:number,name:string,email:string,role:string}"),
      parser.parse_value("{error:string,code:number}")
    )
    [ previous, current ]
  end

  def unchanged_endpoints
    parser = JSONSchemaParser.new([])
    previous = FakeEndpoint.new(
      "GET /health",
      "GET",
      "/health",
      "Health check.",
      [ FakeResponse.new(200, "OK") ],
      parser.parse_value("{status:string}"),
      parser.parse_value("{error:string}")
    )
    current = FakeEndpoint.new(
      "GET /health",
      "GET",
      "/health",
      "Health check.",
      [ FakeResponse.new(200, "OK") ],
      parser.parse_value("{status:string}"),
      parser.parse_value("{error:string}")
    )
    [ previous, current ]
  end

  def new_endpoint
    parser = JSONSchemaParser.new([])
    FakeEndpoint.new(
      "POST /users",
      "POST",
      "/users",
      "Creates a new user account.",
      [ FakeResponse.new(201, "Created"), FakeResponse.new(422, "Validation failed") ],
      parser.parse_value("{id:number,name:string,email:string}"),
      parser.parse_value("{error:string}")
    )
  end

  def removed_endpoint
    parser = JSONSchemaParser.new([])
    FakeEndpoint.new(
      "DELETE /users/{id}",
      "DELETE",
      "/users/{id}",
      "Permanently deletes a user.\nThis action cannot be undone.",
      [ FakeResponse.new(204, "No content"), FakeResponse.new(404, "Not found") ],
      parser.parse_value("{success:boolean}"),
      parser.parse_value("{error:string,code:number}")
    )
  end

  def diff_entities
    parser = JSONSchemaParser.new([])
    previous = FakeEntity.new("User", parser.parse_value("{id:number,name:string,email:string}"))
    current  = FakeEntity.new("User", parser.parse_value("{id:number,name:string,email:string,role:string}"))
    [ previous, current ]
  end

  def unchanged_entities
    parser = JSONSchemaParser.new([])
    previous = FakeEntity.new("Tag", parser.parse_value("{id:number,label:string}"))
    current  = FakeEntity.new("Tag", parser.parse_value("{id:number,label:string}"))
    [ previous, current ]
  end

  def new_entity
    parser = JSONSchemaParser.new([])
    FakeEntity.new("PaginationMeta", parser.parse_value("{page:number,per_page:number,total:number}"))
  end

  def removed_entity
    parser = JSONSchemaParser.new([])
    FakeEntity.new("LegacyToken", parser.parse_value("{token:string,expires_at:string}"))
  end
end
