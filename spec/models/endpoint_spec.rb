require "rails_helper"

describe Endpoint, "#differs_from?" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }
  let!(:v1) { FactoryBot.create(:version, project: project, name: "v1") }
  let!(:v2) { FactoryBot.create(:version, project: project, name: "v2") }

  context "when raw output is unchanged but a referenced entity's body changed" do
    let!(:user_v1) { Entity.create!(version: v1, name: "User", root: "{id:number,name:string}") }
    let!(:user_v2) { Entity.create!(version: v2, name: "User", root: "{id:number,name:string,email:string}") }
    let!(:previous) { Endpoint.create!(version: v1, http_verb: "verb_get", path: "/users", output: "[User]", output_error: "") }
    let!(:current)  { Endpoint.create!(version: v2, http_verb: "verb_get", path: "/users", output: "[User]", output_error: "") }

    it "reports the endpoint as changed" do
      expect(current.differs_from?(previous)).to be true
    end
  end

  context "when raw output differs but expanded output is identical" do
    let!(:user_v1) { Entity.create!(version: v1, name: "User", root: "{id:number,name:string}") }
    let!(:previous) { Endpoint.create!(version: v1, http_verb: "verb_get", path: "/users", output: "[User]", output_error: "") }
    let!(:current)  { Endpoint.create!(version: v2, http_verb: "verb_get", path: "/users", output: "[{id:number,name:string}]", output_error: "") }

    it "reports the endpoint as unchanged" do
      expect(current.differs_from?(previous)).to be false
    end
  end
end
