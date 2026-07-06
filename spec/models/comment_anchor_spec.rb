require "rails_helper"

describe CommentAnchor do
  def anchor(**attrs)
    CommentAnchor.new(**{ scope: "candidate", part: "whole" }.merge(attrs))
  end

  describe "#key" do
    it "returns the logical-identity tuple in column order" do
      a = anchor(scope: "response", part: "output", line: 7,
                 endpoint_path: "/users", endpoint_http_verb: 0, response_code: "200")
      expect(a.key).to eq([ "response", "/users", 0, nil, "200", "output", 7 ])
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
  end

  describe "#to_columns" do
    it "returns every anchor column, with line nil" do
      anchor_obj = CommentAnchor.new(scope: "response", part: "output", endpoint_path: "/users", endpoint_http_verb: 0, response_code: "200")

      expect(anchor_obj.to_columns).to eq(
        scope: "response", part: "output", line: nil,
        endpoint_path: "/users", endpoint_http_verb: 0,
        entity_name: nil, response_code: "200"
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
end
