require "rails_helper"

describe "Entities requests", type: :request do
  let!(:group) { Group.create!(name: "Test group") }
  let!(:user) { User.create!(email_address: "test@example.com", password: "password", group: group) }
  let!(:project) { Project.create!(name: "project", group: group) }

  let!(:another_group) { Group.create!(name: "Test group 2") }
  let!(:another_user) { User.create!(email_address: "test2@example.com", password: "password", group: another_group) }

  let!(:base_candidate) { FactoryBot.create(:candidate, name: "rc1", project: project) }
  let!(:base_version) { FactoryBot.create(:version, project: project, candidate: base_candidate, name: "v1", order: 1) }
  let!(:candidate) { FactoryBot.create(:candidate, name: "rc2", project: project, base_version: base_version) }
  let!(:version) { FactoryBot.create(:version, project: project, candidate: candidate, name: "v2", order: 2) }

  describe "#show" do
    it "expands a referenced entity one level, and stops expanding when asked" do
      FactoryBot.create(:entity, version: base_version, name: "Customer", root: "{id:number}")
      FactoryBot.create(:entity, version: base_version, name: "Order", root: "{customer:Customer}")
      FactoryBot.create(:entity, version: version, name: "Customer", root: "{id:number,vip:boolean}")
      order = FactoryBot.create(:entity, version: version, name: "Order", root: "{customer:Customer}")

      sign_in(user)
      get project_entity_path(project.name, order.id)
      expect(response.body).to include("vip")

      get project_entity_path(project.name, order.id, expanded: "false")
      expect(response.body).to include("Customer")
      expect(response.body).not_to include("vip")
    end

    it "offers the toggle only for an entity that references another one" do
      flat = FactoryBot.create(:entity, version: version, name: "Tag", root: "{label:string}")
      FactoryBot.create(:entity, version: version, name: "Customer", root: "{id:number}")
      referencing = FactoryBot.create(:entity, version: version, name: "Order", root: "{customer:Customer}")

      sign_in(user)
      get project_entity_path(project.name, flat.id)
      expect(response.body).not_to include("expandable#collapse")

      get project_entity_path(project.name, referencing.id)
      expect(response.body).to include("expandable#collapse")
    end

    it "renders an entity the previous version does not carry as an addition" do
      added = FactoryBot.create(:entity, version: version, name: "Tag", root: "{label:string}")

      sign_in(user)
      get project_entity_path(project.name, added.id, kind: "new")
      expect(response.status).to eq(200)
      expect(response.body).to include("Tag")

      get project_entity_path(project.name, added.id)
      expect(response.body).to include("Tag")
    end

    it "renders an entity dropped by this version as a removal" do
      removed = FactoryBot.create(:entity, version: base_version, name: "LegacyToken", root: "{token:string}")

      sign_in(user)
      get project_entity_path(project.name, removed.id, kind: "removed")
      expect(response.body).to include("LegacyToken")
      expect(response.body).not_to include("data-line-pick")
    end

    it "emits comment metadata only when re-rendering for a candidate page" do
      FactoryBot.create(:entity, version: base_version, name: "Customer", root: "{id:number}")
      customer = FactoryBot.create(:entity, version: version, name: "Customer", root: "{id:number,vip:boolean}")
      candidate.comments.create!(author: user, body: "Line thread body", scope: "entity", part: "root",
                                 entity_name: "Customer", line: 1, anchor_snapshot: "{id:number,vip:boolean}")

      sign_in(user)
      get project_entity_path(project.name, customer.id, candidate: candidate.name)
      expect(response.body).to include("Line thread body")
      expect(response.body).to include('data-line-pick-label="Customer → root"')

      get project_entity_path(project.name, customer.id)
      expect(response.body).not_to include("Line thread body")
      expect(response.body).not_to include("data-line-pick")
    end

    it "does not accept users from outside the project group" do
      entity = FactoryBot.create(:entity, version: version, name: "Tag", root: "{label:string}")

      sign_in(another_user)
      get project_entity_path(project.name, entity.id)
      expect(response.status).to eq(302)
      expect(response).to redirect_to("/")
      expect(flash[:alert]).to eq("You are not authorized to perform this action.")
    end
  end
end
