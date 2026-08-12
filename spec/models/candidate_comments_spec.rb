require "rails_helper"

describe CandidateComments do
  let(:candidate) { FactoryBot.create(:candidate) }
  let(:endpoint) { FactoryBot.create(:endpoint, path: "/users", http_verb: "verb_get") }
  let(:other_endpoint) { FactoryBot.create(:endpoint, path: "/tasks", http_verb: "verb_get") }
  let(:entity) { FactoryBot.create(:entity, name: "User") }

  def comments = described_class.for(candidate)

  describe "when a path param is renamed" do
    let(:renamed) { FactoryBot.create(:endpoint, path: "/users/:user_id", http_verb: "verb_get", input: "{name:string}") }

    def comment_on(path, trait, **attrs)
      FactoryBot.create(:comment, trait, candidate: candidate, endpoint_path: path, **attrs)
    end

    it "keeps an endpoint thread attached" do
      thread = comment_on("/users/:id", :endpoint_scope)

      expect(comments.threads_for("endpoint", endpoint: renamed, part: "whole")).to eq([ thread ])
    end

    it "keeps the endpoint's comment card" do
      comment_on("/users/:id", :endpoint_scope)

      expect(comments.card_for_endpoint(renamed)[:whole].size).to eq(1)
    end

    it "keeps an input line comment attached" do
      comment_on("/users/:id", :endpoint_input, line: 0, anchor_snapshot: renamed.input)

      expect(comments.endpoint_input_lines(renamed).fresh.size).to eq(1)
    end

    it "still keeps a different endpoint's comments apart" do
      comment_on("/tasks/:id", :endpoint_scope)

      expect(comments.threads_for("endpoint", endpoint: renamed, part: "whole")).to eq([])
    end
  end

  describe "without a candidate" do
    it "answers empty to every reader" do
      FactoryBot.create(:comment, :endpoint_scope, candidate: candidate)
      none = described_class.for(nil)

      expect(none.threads_for("endpoint", endpoint: endpoint)).to eq([])
      expect(none.sidebar_count(CommentAnchor.for_endpoint(endpoint))).to eq(0)
      expect(none.card_for_endpoint(endpoint)).to eq(whole: [], lines: [])
      expect(none.card_for_entity(entity)).to eq(whole: [], lines: [])
      expect(none.response_output_lines(endpoint, "200")).to eq(described_class::LineComments.new(fresh: [], outdated: []))
      expect(none.entity_root_lines(entity)).to eq(described_class::LineComments.new(fresh: [], outdated: []))
      expect(none.endpoint_input_lines(endpoint)).to eq(described_class::LineComments.new(fresh: [], outdated: []))
    end
  end

  describe "#threads_for" do
    it "finds threads by scope and identity, sorted by creation time" do
      input = FactoryBot.create(:comment, :endpoint_input, candidate: candidate, created_at: 3.days.ago)
      note = FactoryBot.create(:comment, :endpoint_scope, candidate: candidate, part: "note", created_at: 2.days.ago)
      whole = FactoryBot.create(:comment, :endpoint_scope, candidate: candidate, created_at: 1.day.ago)
      entity_thread = FactoryBot.create(:comment, :entity_scope, candidate: candidate)
      response_thread = FactoryBot.create(:comment, :response_scope, candidate: candidate)

      expect(comments.threads_for("endpoint", endpoint: endpoint)).to eq([ input, note, whole ])

      expect(comments.threads_for("endpoint", endpoint: endpoint, part: "whole")).to eq([ whole ])
      expect(comments.threads_for("endpoint", endpoint: endpoint, part: "note")).to eq([ note ])
      expect(comments.threads_for("endpoint", endpoint: endpoint, part: "input")).to eq([ input ])

      expect(comments.threads_for("entity", entity: entity)).to eq([ entity_thread ])
      expect(comments.threads_for("response", endpoint: endpoint, response_code: "200")).to eq([ response_thread ])

      expect(comments.threads_for("endpoint", endpoint: other_endpoint)).to eq([])
      expect(comments.threads_for("response", endpoint: endpoint, response_code: "404")).to eq([])
    end

    it "excludes line-anchored threads" do
      FactoryBot.create(:comment, :response_scope, candidate: candidate, part: "output", line: 2, anchor_snapshot: "x")

      expect(comments.threads_for("response", endpoint: endpoint, response_code: "200")).to eq([])
    end
  end

  describe "param threads" do
    let(:param_endpoint) { FactoryBot.create(:endpoint, path: "/users/:id", http_verb: "verb_get") }

    it "finds a thread by endpoint identity and param name" do
      thread = FactoryBot.create(:comment, :param_scope, candidate: candidate)

      expect(comments.threads_for("param", endpoint: param_endpoint, param_name: "id", param_location: "path")).to eq([ thread ])
      expect(comments.threads_for("param", endpoint: param_endpoint, param_name: "slug", param_location: "path")).to eq([])
    end

    it "keeps two params on one endpoint apart" do
      on_id = FactoryBot.create(:comment, :param_scope, candidate: candidate)
      on_slug = FactoryBot.create(:comment, :param_scope, candidate: candidate,
                                  endpoint_path: "/users/:id/:slug", param_name: "slug")
      endpoint = FactoryBot.create(:endpoint, path: "/users/:id/:slug", http_verb: "verb_get")

      expect(comments.threads_for("param", endpoint: endpoint, param_name: "slug", param_location: "path")).to eq([ on_slug ])
      expect(comments.threads_for("param", endpoint: param_endpoint, param_name: "id", param_location: "path")).to eq([ on_id ])
    end

    it "keeps a path param and a query param of the same name apart" do
      on_path = FactoryBot.create(:comment, :param_scope, candidate: candidate)
      on_query = FactoryBot.create(:comment, :param_scope, candidate: candidate, param_location: "query")

      expect(comments.threads_for("param", endpoint: param_endpoint, param_name: "id", param_location: "path")).to eq([ on_path ])
      expect(comments.threads_for("param", endpoint: param_endpoint, param_name: "id", param_location: "query")).to eq([ on_query ])
    end

    # Identity keys on the name, so unlike an endpoint thread a param thread does
    # not survive its param being renamed.
    it "orphans a thread when the param is renamed" do
      FactoryBot.create(:comment, :param_scope, candidate: candidate)
      renamed = FactoryBot.create(:endpoint, path: "/users/:user_id", http_verb: "verb_get")

      expect(comments.threads_for("param", endpoint: renamed, param_name: "user_id", param_location: "path")).to eq([])
    end

    it "counts into the endpoint's card and sidebar count" do
      FactoryBot.create(:comment, :param_scope, candidate: candidate)

      expect(comments.card_for_endpoint(param_endpoint)[:whole].size).to eq(1)
      expect(comments.sidebar_count(CommentAnchor.for_endpoint(param_endpoint))).to eq(1)
    end
  end

  describe "#sidebar_count" do
    it "counts every thread under the target, not replies" do
      root = FactoryBot.create(:comment, :endpoint_scope, candidate: candidate)
      FactoryBot.create(:comment, candidate: candidate, parent: root, body: "A reply")
      FactoryBot.create(:comment, :endpoint_scope, candidate: candidate, part: "note")
      FactoryBot.create(:comment, :endpoint_input, candidate: candidate)
      FactoryBot.create(:comment, :response_scope, candidate: candidate)
      FactoryBot.create(:comment, :entity_scope, candidate: candidate)

      expect(comments.sidebar_count(CommentAnchor.for_endpoint(endpoint))).to eq(4)
      expect(comments.sidebar_count(CommentAnchor.for_endpoint(other_endpoint))).to eq(0)
      expect(comments.sidebar_count(CommentAnchor.for_entity(entity))).to eq(1)
      expect(comments.sidebar_count(CommentAnchor.for_entity(FactoryBot.create(:entity, name: "Task")))).to eq(0)
    end
  end

  describe "#card_for_endpoint / #card_for_entity" do
    it "splits a card's threads into whole-scope and line-anchored" do
      whole = FactoryBot.create(:comment, :endpoint_scope, candidate: candidate)
      response_whole = FactoryBot.create(:comment, :response_scope, candidate: candidate)
      line = FactoryBot.create(:comment, :response_scope, candidate: candidate, part: "output", line: 2, anchor_snapshot: "x")
      input_whole = FactoryBot.create(:comment, :endpoint_input, candidate: candidate)
      input_line = FactoryBot.create(:comment, :endpoint_input, candidate: candidate, line: 1, anchor_snapshot: "x")
      entity_whole = FactoryBot.create(:comment, :entity_scope, candidate: candidate)
      entity_line = FactoryBot.create(:comment, :entity_scope, candidate: candidate, part: "root", line: 0, anchor_snapshot: "x")

      # the card is what the React edit form renders, so input rides along with no extra wiring
      endpoint_card = comments.card_for_endpoint(endpoint)
      expect(endpoint_card[:whole]).to contain_exactly(whole, response_whole, input_whole)
      expect(endpoint_card[:lines]).to eq([ input_line, line ])

      entity_card = comments.card_for_entity(entity)
      expect(entity_card[:whole]).to eq([ entity_whole ])
      expect(entity_card[:lines]).to eq([ entity_line ])

      expect(comments.card_for_endpoint(other_endpoint)).to eq(whole: [], lines: [])
    end
  end

  describe "line readers" do
    it "splits line-anchored threads into fresh and outdated, ordered by line" do
      FactoryBot.create(:response, endpoint: endpoint, code: "200", output: "{id:number}")
      entity.update!(root: "{name:string}")

      second = FactoryBot.create(:comment, :response_scope, candidate: candidate, part: "output", line: 5, anchor_snapshot: "{id:number}")
      first = FactoryBot.create(:comment, :response_scope, candidate: candidate, part: "output", line: 2, anchor_snapshot: "{id:number}")
      stale = FactoryBot.create(:comment, :response_scope, candidate: candidate, part: "output", line: 3, anchor_snapshot: "{id:number,legacy:string}")
      entity_line = FactoryBot.create(:comment, :entity_scope, candidate: candidate, part: "root", line: 0, anchor_snapshot: "{name:string}")
      entity_stale = FactoryBot.create(:comment, :entity_scope, candidate: candidate, part: "root", line: 1, anchor_snapshot: "{name:string,legacy:string}")

      response_lines = comments.response_output_lines(endpoint, "200")
      entity_lines = comments.entity_root_lines(entity)

      expect(response_lines.fresh).to eq([ first, second ])
      expect(entity_lines.fresh).to eq([ entity_line ])

      expect(response_lines.outdated).to eq([ stale ])
      expect(entity_lines.outdated).to eq([ entity_stale ])

      expect(response_lines.by_line).to eq(2 => [ first ], 5 => [ second ])

      expect(comments.response_output_lines(endpoint, "404").fresh).to eq([])
    end

    it "splits endpoint input threads against the raw input string" do
      endpoint.update!(input: "{name:string}")

      second = FactoryBot.create(:comment, :endpoint_input, candidate: candidate, line: 4, anchor_snapshot: "{name:string}")
      first = FactoryBot.create(:comment, :endpoint_input, candidate: candidate, line: 1, anchor_snapshot: "{name:string}")
      stale = FactoryBot.create(:comment, :endpoint_input, candidate: candidate, line: 2, anchor_snapshot: "{name:string,legacy:string}")

      input_lines = comments.endpoint_input_lines(endpoint)

      expect(input_lines.fresh).to eq([ first, second ])
      expect(input_lines.outdated).to eq([ stale ])
      expect(input_lines.by_line).to eq(1 => [ first ], 4 => [ second ])

      expect(comments.endpoint_input_lines(other_endpoint).fresh).to eq([])
    end

    it "outdates input threads once the request body is dropped" do
      thread = FactoryBot.create(:comment, :endpoint_input, candidate: candidate, line: 1, anchor_snapshot: "{name:string}")
      endpoint.update!(input: "")

      expect(comments.endpoint_input_lines(endpoint).outdated).to eq([ thread ])
    end

    it "keeps input and response threads in separate buckets" do
      endpoint.update!(input: "{name:string}")
      FactoryBot.create(:response, endpoint: endpoint, code: "200", output: "{id:number}")

      input_thread = FactoryBot.create(:comment, :endpoint_input, candidate: candidate, line: 1, anchor_snapshot: "{name:string}")
      output_thread = FactoryBot.create(:comment, :response_scope, candidate: candidate, part: "output", line: 1, anchor_snapshot: "{id:number}")

      expect(comments.endpoint_input_lines(endpoint).fresh).to eq([ input_thread ])
      expect(comments.response_output_lines(endpoint, "200").fresh).to eq([ output_thread ])
    end

    it "treats every thread as outdated when the anchored text is gone" do
      orphan = FactoryBot.create(:comment, :response_scope, candidate: candidate, part: "output", line: 2, anchor_snapshot: "{id:number}")

      expect(comments.response_output_lines(endpoint, "200").outdated).to eq([ orphan ])
    end
  end

  describe "auth methods" do
    let(:auth_method) { FactoryBot.create(:auth_method, name: "UserToken", kind: "bearer") }
    let(:other_method) { FactoryBot.create(:auth_method, name: "AdminBasic", kind: "basic") }

    it "attaches a thread to the method it names" do
      thread = FactoryBot.create(:comment, :auth_method_scope, candidate: candidate)

      expect(comments.threads_for("auth_method", auth_method: auth_method, part: "whole")).to eq([ thread ])
    end

    it "keeps another method's threads apart" do
      FactoryBot.create(:comment, :auth_method_scope, candidate: candidate)

      expect(comments.threads_for("auth_method", auth_method: other_method, part: "whole")).to eq([])
    end

    it "builds the method's comment card" do
      FactoryBot.create(:comment, :auth_method_scope, candidate: candidate)

      expect(comments.card_for_auth_method(auth_method)[:whole].size).to eq(1)
    end

    it "counts a method's threads in the sidebar" do
      FactoryBot.create(:comment, :auth_method_scope, candidate: candidate)

      expect(comments.sidebar_count(CommentAnchor.for_auth_method(auth_method))).to eq(1)
    end

    # A thread on an endpoint's auth row belongs to the endpoint's card, not the
    # method's — it is about this endpoint's choice, not about the method itself.
    it "files a thread on an endpoint's auth row under the endpoint" do
      thread = FactoryBot.create(:comment, :endpoint_auth, candidate: candidate)

      expect(comments.threads_for("endpoint", endpoint: endpoint, part: "auth")).to eq([ thread ])
      expect(comments.card_for_endpoint(endpoint)[:whole]).to eq([ thread ])
      expect(comments.card_for_auth_method(auth_method)[:whole]).to eq([])
    end
  end
end
