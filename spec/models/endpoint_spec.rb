require "rails_helper"

describe Endpoint, "#differs_from?" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }
  let!(:v1) { FactoryBot.create(:version, project: project, name: "v1") }
  let!(:v2) { FactoryBot.create(:version, project: project, name: "v2") }

  it "reports no difference when endpoints are identical" do
    e1 = FactoryBot.create(:endpoint, version: v1, path: "/x", http_verb: "verb_get", note: "hello")
    FactoryBot.create(:response, endpoint: e1, code: "200", output: "string")
    e2 = FactoryBot.create(:endpoint, version: v2, path: "/x", http_verb: "verb_get", note: "hello")
    FactoryBot.create(:response, endpoint: e2, code: "200", output: "string")
    expect(e2.differs_from?(e1)).to be(false)
  end

  it "differs when a note changes" do
    e1 = FactoryBot.create(:endpoint, version: v1, path: "/x", http_verb: "verb_get", note: "old note")
    e2 = FactoryBot.create(:endpoint, version: v2, path: "/x", http_verb: "verb_get", note: "new note")
    expect(e2.differs_from?(e1)).to be(true)
  end

  it "differs when a response schema changes" do
    e1 = FactoryBot.create(:endpoint, version: v1, path: "/x", http_verb: "verb_get")
    FactoryBot.create(:response, endpoint: e1, code: "200", output: "string")
    e2 = FactoryBot.create(:endpoint, version: v2, path: "/x", http_verb: "verb_get")
    FactoryBot.create(:response, endpoint: e2, code: "200", output: "number")
    expect(e2.differs_from?(e1)).to be(true)
  end
end
