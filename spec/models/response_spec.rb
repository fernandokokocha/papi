require "rails_helper"

describe Response, type: :model do
  let(:group) { FactoryBot.create(:group) }
  let(:project) { FactoryBot.create(:project, group: group) }
  let(:candidate) { FactoryBot.create(:candidate, project: project) }
  let(:version) { FactoryBot.create(:version, project: project, candidate: candidate) }
  let(:endpoint) { FactoryBot.create(:endpoint, version: version) }

  describe "#parsed_output" do
    it "parses an empty output as Nothing" do
      response = FactoryBot.create(:response, endpoint: endpoint, code: "204", output: "")
      expect(response.parsed_output).to be_a(Node::Nothing)
    end

    it "parses a primitive output" do
      response = FactoryBot.create(:response, endpoint: endpoint, code: "200", output: "string")
      expect(response.parsed_output).to be_a(Node::Primitive)
    end

    it "resolves entity references using the version entities" do
      FactoryBot.create(:entity, version: version, name: "User", root: "{ name: string }")
      response = FactoryBot.create(:response, endpoint: endpoint, code: "200", output: "User")
      expect(response.parsed_output).to be_a(Node::Entity)
    end
  end
end
