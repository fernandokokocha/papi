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

    @preview_comments = preview_comments
  end

  private

  # In-memory comment threads — one per kind — so the design page previews the
  # real comments/thread partial. Unsaved records: Pundit still infers
  # CommentPolicy, and resolve? (author == candidate.author) is false for the
  # unauthenticated preview, so no id-dependent action routes are hit.
  def preview_comments
    author   = User.new(id: 1, email_address: "one@example.com")
    reviewer = User.new(id: 2, email_address: "two@example.com")
    candidate = Candidate.new(id: 1, name: "preview", project: Project.new(name: "demo"), author: author)

    on_endpoint = { endpoint_path: "/users", endpoint_http_verb: Endpoint.http_verbs[:verb_get] }

    build = ->(id, attrs, by:, body:, ago:) do
      Comment.new({ id: id, candidate: candidate, author: by, body: body, created_at: ago.ago }.merge(attrs))
    end

    conversation = build.(1, { scope: "candidate", part: "whole" },
      by: author, body: "Ready for another pass whenever you have a minute.", ago: 3.hours)

    endpoint = build.(2, { scope: "endpoint", part: "whole", **on_endpoint },
      by: reviewer, body: "Is this idempotent?", ago: 2.hours)
    endpoint.replies.build(id: 20, candidate: candidate, author: author,
      body: "It is — safe to retry.", created_at: 1.hour.ago)

    note = build.(3, { scope: "endpoint", part: "note", **on_endpoint },
      by: author, body: "Mention the rate limit here.", ago: 100.minutes)

    response = build.(4, { scope: "response", part: "whole", response_code: "200", **on_endpoint },
      by: reviewer, body: "Is email always present?", ago: 90.minutes)

    line = build.(5, { scope: "response", part: "output", line: 3, response_code: "200", **on_endpoint },
      by: author, body: "Should this be nullable?", ago: 80.minutes)
    line.resolved_at = 30.minutes.ago
    line.resolved_by = reviewer

    entity = build.(6, { scope: "entity", part: "whole", entity_name: "User" },
      by: author, body: "Renamed total_cents → amount.", ago: 70.minutes)

    [ conversation, endpoint, note, response, line, entity ]
  end

  FakeResponse = Struct.new(:code, :note, :parsed_output) do
    def output = parsed_output.serialize
  end
  FakeEndpoint = Struct.new(:name, :verb, :path, :note, :responses) do
    def http_verb
      "verb_#{verb.downcase}"
    end

    def differs_from?(previous)
      DiffText::FromNotes.new(previous.note, note).any_changes? ||
        DiffResponses::FromResponses.new(previous.responses, responses).any_changes?
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
      [
        FakeResponse.new(200, "Success", parser.parse_value("{id:number,name:string,email:string}")),
        FakeResponse.new(404, "Not found", parser.parse_value("{error:string}"))
      ]
    )
    current = FakeEndpoint.new(
      "GET /users",
      "GET",
      "/users",
      "Returns a paginated list of users.\nUse the page and per_page params to paginate.",
      [
        FakeResponse.new(200, "Success", parser.parse_value("{id:number,name:string,email:string,role:string}")),
        FakeResponse.new(400, "Bad request", parser.parse_value("{error:string,code:number}")),
        FakeResponse.new(404, "Not found", parser.parse_value("{error:string}"))
      ]
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
      [ FakeResponse.new(200, "OK", parser.parse_value("{status:string}")) ]
    )
    current = FakeEndpoint.new(
      "GET /health",
      "GET",
      "/health",
      "Health check.",
      [ FakeResponse.new(200, "OK", parser.parse_value("{status:string}")) ]
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
      [
        FakeResponse.new(201, "Created", parser.parse_value("{id:number,name:string,email:string}")),
        FakeResponse.new(422, "Validation failed", parser.parse_value("{error:string}"))
      ]
    )
  end

  def removed_endpoint
    parser = JSONSchemaParser.new([])
    FakeEndpoint.new(
      "DELETE /users/{id}",
      "DELETE",
      "/users/{id}",
      "Permanently deletes a user.\nThis action cannot be undone.",
      [
        FakeResponse.new(204, "No content", parser.parse_value("{success:boolean}")),
        FakeResponse.new(404, "Not found", parser.parse_value("{error:string,code:number}"))
      ]
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
