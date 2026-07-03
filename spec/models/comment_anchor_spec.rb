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
end
