require "rails_helper"

describe CommentAnchor do
  def anchor(**attrs)
    CommentAnchor.new(**{ scope: "candidate", part: "whole" }.merge(attrs))
  end

  describe "#key" do
    it "returns the logical-identity tuple in column order" do
      a = anchor(scope: "response", part: "output", line: 7,
                 endpoint_path: "/users", endpoint_http_verb: 0, response_code: "200")
      expect(a.key).to eq([ "response", "/users", 0, nil, "200", nil, "output", 7 ])
    end
  end

  describe "#errors" do
    it "is empty for a valid candidate/whole anchor" do
      expect(anchor.errors).to eq([])
    end

    it "flags an unknown scope" do
      expect(anchor(scope: "nope").errors).to eq([ [ :scope, "is not a valid scope" ] ])
    end

    it "flags a part that is not legal for the scope" do
      expect(anchor(scope: "candidate", part: "note").errors).to include([ :part, a_string_including("not valid") ])
    end

    it "requires the scope's identity columns" do
      a = anchor(scope: "endpoint", part: "whole", endpoint_path: nil, endpoint_http_verb: 0)
      expect(a.errors).to include([ :endpoint_path, a_string_including("required") ])
    end

    it "treats GET (verb 0) as present, not missing" do
      a = anchor(scope: "endpoint", part: "whole", endpoint_path: "/users", endpoint_http_verb: 0)
      expect(a.errors).to eq([])
    end

    it "forbids identity columns from other scopes" do
      a = anchor(scope: "candidate", part: "whole", entity_name: "User")
      expect(a.errors).to include([ :entity_name, a_string_including("must be blank") ])
    end

    it "requires response_code for a response anchor" do
      a = anchor(scope: "response", part: "whole",
                 endpoint_path: "/users", endpoint_http_verb: 0, response_code: nil)
      expect(a.errors).to include([ :response_code, a_string_including("required") ])
    end

    it "requires param_name for a param anchor" do
      a = anchor(scope: "param", part: "whole", endpoint_path: "/users/:id", endpoint_http_verb: 0)
      expect(a.errors).to include([ :param_name, a_string_including("required") ])
    end

    it "accepts a param anchor carrying its endpoint and name" do
      a = anchor(scope: "param", part: "whole",
                 endpoint_path: "/users/:id", endpoint_http_verb: 0, param_name: "id")
      expect(a.errors).to eq([])
    end

    it "forbids param_name on other scopes" do
      a = anchor(scope: "endpoint", part: "whole",
                 endpoint_path: "/users", endpoint_http_verb: 0, param_name: "id")
      expect(a.errors).to include([ :param_name, a_string_including("must be blank") ])
    end

    it "allows only the whole part on a param" do
      a = anchor(scope: "param", part: "note",
                 endpoint_path: "/users/:id", endpoint_http_verb: 0, param_name: "id")
      expect(a.errors).to include([ :part, a_string_including("not valid") ])
    end

    it "accepts input as an endpoint part, with or without a line" do
      region = anchor(scope: "endpoint", part: "input", endpoint_path: "/users", endpoint_http_verb: 1)
      line = anchor(scope: "endpoint", part: "input", line: 3, endpoint_path: "/users", endpoint_http_verb: 1)

      expect(region.errors).to eq([])
      expect(line.errors).to eq([])
    end

    it "allows a line only on a text part" do
      valid = anchor(scope: "response", part: "output", line: 3,
                     endpoint_path: "/users", endpoint_http_verb: 0, response_code: "200")
      invalid = anchor(scope: "response", part: "whole", line: 3,
                       endpoint_path: "/users", endpoint_http_verb: 0, response_code: "200")
      expect(valid.errors).to eq([])
      expect(invalid.errors).to include([ :line, a_string_including("text part") ])
    end
  end

  describe ".from_params" do
    it "defaults to the candidate/whole anchor when scope and part are blank" do
      anchor_obj = CommentAnchor.from_params({ "body" => "hi" })

      expect(anchor_obj.scope).to eq("candidate")
      expect(anchor_obj.part).to eq("whole")
      expect(anchor_obj.errors).to be_empty
    end

    it "builds an endpoint anchor and coerces the verb to an integer" do
      anchor_obj = CommentAnchor.from_params(
        "scope" => "endpoint", "part" => "note",
        "endpoint_path" => "/users", "endpoint_http_verb" => "0"
      )

      expect(anchor_obj.scope).to eq("endpoint")
      expect(anchor_obj.part).to eq("note")
      expect(anchor_obj.endpoint_path).to eq("/users")
      expect(anchor_obj.endpoint_http_verb).to eq(0)
      expect(anchor_obj.errors).to be_empty
    end

    it "leaves irrelevant identity columns nil" do
      anchor_obj = CommentAnchor.from_params("scope" => "entity", "part" => "whole", "entity_name" => "User")

      expect(anchor_obj.entity_name).to eq("User")
      expect(anchor_obj.endpoint_path).to be_nil
      expect(anchor_obj.response_code).to be_nil
    end

    it "parses line to an integer and leaves it nil when blank" do
      expect(described_class.from_params({ "scope" => "response", "part" => "output", "line" => "4" }).line).to eq(4)
      expect(described_class.from_params({ "scope" => "response", "part" => "output", "line" => "" }).line).to be_nil
    end
  end

  describe "#to_columns" do
    it "returns every anchor column, with line nil" do
      anchor_obj = CommentAnchor.new(scope: "response", part: "output", endpoint_path: "/users", endpoint_http_verb: 0, response_code: "200")

      expect(anchor_obj.to_columns).to eq(
        scope: "response", part: "output", line: nil,
        endpoint_path: "/users", endpoint_http_verb: 0,
        entity_name: nil, response_code: "200", param_name: nil
      )
    end
  end

  describe "#dom_id" do
    it "is stable for equal anchors and differs by part" do
      whole = CommentAnchor.new(scope: "endpoint", part: "whole", endpoint_path: "/users", endpoint_http_verb: 0)
      whole_again = CommentAnchor.new(scope: "endpoint", part: "whole", endpoint_path: "/users", endpoint_http_verb: 0)
      note = CommentAnchor.new(scope: "endpoint", part: "note", endpoint_path: "/users", endpoint_http_verb: 0)

      expect(whole.dom_id).to eq(whole_again.dom_id)
      expect(whole.dom_id).not_to eq(note.dom_id)
      expect(whole.dom_id).to match(/\Acomment_anchor_[0-9a-f]{32}\z/)
    end
  end

  describe "#label" do
    it "reads response output down to the line" do
      a = anchor(scope: "response", part: "output", line: 0,
                 endpoint_path: "/users", endpoint_http_verb: 0, response_code: "200")
      expect(a.label).to eq("GET /users → 200 → output · line 0")
    end

    it "reads an entity root" do
      a = anchor(scope: "entity", part: "root", line: 0, entity_name: "User")
      expect(a.label).to eq("User → root · line 0")
    end

    it "reads an endpoint input" do
      a = anchor(scope: "endpoint", part: "input", line: 2, endpoint_path: "/users", endpoint_http_verb: 1)
      expect(a.label).to eq("POST /users → input · line 2")
    end

    it "reads a param, keeping the endpoint's own param names" do
      a = anchor(scope: "param", part: "whole",
                 endpoint_path: "/users/:id", endpoint_http_verb: 0, param_name: "id")
      expect(a.label).to eq("GET /users/:id → :id")
    end
  end

  describe "#kind" do
    it "names the coarse kind, preferring line over part over scope" do
      # the scope names it
      expect(anchor(scope: "candidate", part: "whole", line: nil,
                    endpoint_path: nil, endpoint_http_verb: nil,
                    entity_name: nil, response_code: nil).kind).to eq(:conversation)
      expect(anchor(scope: "endpoint", part: "whole", line: nil,
                    endpoint_path: "/users", endpoint_http_verb: 0,
                    entity_name: nil, response_code: nil).kind).to eq(:endpoint)
      expect(anchor(scope: "entity", part: "whole", line: nil,
                    endpoint_path: nil, endpoint_http_verb: nil,
                    entity_name: "User", response_code: nil).kind).to eq(:entity)
      expect(anchor(scope: "response", part: "whole", line: nil,
                    endpoint_path: "/users", endpoint_http_verb: 0,
                    entity_name: nil, response_code: "200").kind).to eq(:response)
      expect(anchor(scope: "param", part: "whole", line: nil,
                    endpoint_path: "/users/:id", endpoint_http_verb: 0,
                    entity_name: nil, response_code: nil, param_name: "id").kind).to eq(:param)

      # a note part beats the scope
      expect(anchor(scope: "endpoint", part: "note", line: nil,
                    endpoint_path: "/users", endpoint_http_verb: 0,
                    entity_name: nil, response_code: nil).kind).to eq(:note)

      # so does an input part
      expect(anchor(scope: "endpoint", part: "input", line: nil,
                    endpoint_path: "/users", endpoint_http_verb: 0,
                    entity_name: nil, response_code: nil).kind).to eq(:input)

      # a line beats both
      expect(anchor(scope: "endpoint", part: "note", line: 3,
                    endpoint_path: "/users", endpoint_http_verb: 0,
                    entity_name: nil, response_code: nil).kind).to eq(:line)
      expect(anchor(scope: "entity", part: "root", line: 0,
                    endpoint_path: nil, endpoint_http_verb: nil,
                    entity_name: "User", response_code: nil).kind).to eq(:line)
      expect(anchor(scope: "endpoint", part: "input", line: 1,
                    endpoint_path: "/users", endpoint_http_verb: 0,
                    entity_name: nil, response_code: nil).kind).to eq(:line)
    end
  end

  describe ".for_endpoint_input" do
    it "builds the line-part anchor from an endpoint record" do
      endpoint = FactoryBot.build(:endpoint, path: "/users", http_verb: "verb_post")
      built = described_class.for_endpoint_input(endpoint)

      expect(built.key).to eq([ "endpoint", "/users", 1, nil, nil, nil, "input", nil ])
    end
  end

  describe ".for_endpoint_param" do
    it "builds the param anchor from an endpoint record and a param name" do
      endpoint = FactoryBot.build(:endpoint, path: "/users/:id", http_verb: "verb_get")
      built = described_class.for_endpoint_param(endpoint, "id")

      expect(built.key).to eq([ "param", "/users/:", 0, nil, nil, "id", "whole", nil ])
    end

    it "keeps the raw path but erases the param name from the endpoint identity" do
      endpoint = FactoryBot.build(:endpoint, path: "/users/:id", http_verb: "verb_get")
      built = described_class.for_endpoint_param(endpoint, "id")

      expect(built.endpoint_path).to eq("/users/:id")
      expect(built.param_name).to eq("id")
    end
  end

  describe "#without_line" do
    it "keeps the identity and drops the line" do
      with_line = anchor(scope: "response", part: "output", endpoint_path: "/users",
                         endpoint_http_verb: 0, response_code: "200", line: 4)
      expect(with_line.without_line.key).to eq([ "response", "/users", 0, nil, "200", nil, "output", nil ])
    end
  end

  describe "#current_output" do
    let(:version) { FactoryBot.create :version }
    let(:endpoint) { FactoryBot.create :endpoint, version: version, path: "/users", http_verb: "verb_get", input: "{name:string}" }

    before do
      FactoryBot.create :response, endpoint: endpoint, code: "200", output: "{total:number,items:[User]}"
      FactoryBot.create :entity, version: version, name: "User", root: "{id:number}"
    end

    it "returns the response output for a response/output anchor" do
      a = anchor(scope: "response", part: "output", endpoint_path: "/users", endpoint_http_verb: 0, response_code: "200")
      expect(a.current_output(version)).to eq("{total:number,items:[User]}")
    end

    it "returns the entity root for an entity/root anchor" do
      a = anchor(scope: "entity", part: "root", entity_name: "User")
      expect(a.current_output(version)).to eq("{id:number}")
    end

    it "returns the raw input string for an endpoint/input anchor" do
      a = anchor(scope: "endpoint", part: "input", endpoint_path: "/users", endpoint_http_verb: 0)
      expect(a.current_output(version)).to eq("{name:string}")
    end

    it "returns the empty input of a body-less endpoint, not nil" do
      FactoryBot.create :endpoint, version: version, path: "/health", http_verb: "verb_get", input: ""
      a = anchor(scope: "endpoint", part: "input", endpoint_path: "/health", endpoint_http_verb: 0)

      expect(a.current_output(version)).to eq("")
    end

    it "raises when the target is missing — nothing validates that an anchor's target exists" do
      # the response is missing
      expect {
        anchor(scope: "response", part: "output", line: nil,
               endpoint_path: "/users", endpoint_http_verb: 0,
               entity_name: nil, response_code: "404").current_output(version)
      }.to raise_error(NoMethodError)

      # the endpoint is missing
      expect {
        anchor(scope: "response", part: "output", line: nil,
               endpoint_path: "/nope", endpoint_http_verb: 0,
               entity_name: nil, response_code: "200").current_output(version)
      }.to raise_error(NoMethodError)

      # the entity is missing
      expect {
        anchor(scope: "entity", part: "root", line: nil,
               endpoint_path: nil, endpoint_http_verb: nil,
               entity_name: "Nope", response_code: nil).current_output(version)
      }.to raise_error(NoMethodError)

      # the endpoint behind an input anchor is missing
      expect {
        anchor(scope: "endpoint", part: "input", line: nil,
               endpoint_path: "/nope", endpoint_http_verb: 0,
               entity_name: nil, response_code: nil).current_output(version)
      }.to raise_error(NoMethodError)
    end

    it "picks the endpoint by verb as well as path" do
      FactoryBot.create :endpoint, version: version, path: "/users", http_verb: "verb_post", input: "{name:string,email:string}"

      get_anchor = anchor(scope: "endpoint", part: "input", endpoint_path: "/users", endpoint_http_verb: 0)
      post_anchor = anchor(scope: "endpoint", part: "input", endpoint_path: "/users", endpoint_http_verb: 1)

      expect(get_anchor.current_output(version)).to eq("{name:string}")
      expect(post_anchor.current_output(version)).to eq("{name:string,email:string}")
    end
  end
end
