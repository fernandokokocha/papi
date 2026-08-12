require "rails_helper"

describe AuthMethod, "#differs_from?" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }
  let!(:before_version) { FactoryBot.create(:version, project: project, name: "v1") }
  let!(:after_version) { FactoryBot.create(:version, project: project, name: "v2") }

  def method_in(version, attributes)
    FactoryBot.create(:auth_method, { version: version, name: "UserToken" }.merge(attributes))
  end

  it "sees a kind swapped for another" do
    before = method_in(before_version, kind: "bearer")
    after = method_in(after_version, kind: "basic")

    expect(after.differs_from?(before)).to eq(true)
  end

  it "sees a rewritten note" do
    before = method_in(before_version, note: "Token from POST /sessions")
    after = method_in(after_version, note: "Token from POST /login")

    expect(after.differs_from?(before)).to eq(true)
  end

  it "reads an untouched method as unchanged" do
    before = method_in(before_version, kind: "bearer", note: "Token from POST /sessions")
    after = method_in(after_version, kind: "bearer", note: "Token from POST /sessions")

    expect(after.differs_from?(before)).to eq(false)
  end
end

describe AuthMethod, "in a comparison" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }
  let!(:before_version) { FactoryBot.create(:version, project: project, name: "v1", order: 1) }
  let!(:after_version) { FactoryBot.create(:version, project: project, name: "v2", order: 2) }

  it "categorises by name across two versions" do
    FactoryBot.create(:auth_method, version: before_version, name: "UserToken", kind: "bearer")
    FactoryBot.create(:auth_method, version: before_version, name: "LegacyKey", kind: "basic")
    FactoryBot.create(:auth_method, version: after_version, name: "UserToken", kind: "basic")
    FactoryBot.create(:auth_method, version: after_version, name: "AdminBasic", kind: "basic")

    comparison = Comparison.new(before_version.reload, after_version.reload)

    expect(comparison.auth_methods.map { |m| [ m.name, m.annotation ] }).to eq(
      [ [ "AdminBasic", "added" ], [ "LegacyKey", "removed" ], [ "UserToken", "changed" ] ]
    )
  end
end

describe AuthMethod, "when a new version is cut" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }
  let!(:version) { FactoryBot.create(:version, project: project, name: "v1") }

  it "is copied along with the endpoint that names it" do
    FactoryBot.create(:auth_method, version: version, name: "UserToken", kind: "basic")
    FactoryBot.create(:endpoint, version: version, path: "/users", auth: "UserToken")

    copy = version.reload.amoeba_dup
    copy.name = "v2"
    copy.save!

    expect(copy.reload.auth_methods.map(&:kind)).to eq([ "basic" ])
    expect(copy.endpoints.first.auth_method.name).to eq("UserToken")
  end
end

describe Endpoint, "#auth_method" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }
  let!(:version) { FactoryBot.create(:version, project: project, name: "v1") }

  it "resolves the name the endpoint carries" do
    FactoryBot.create(:auth_method, version: version, name: "UserToken", kind: "bearer")
    endpoint = FactoryBot.create(:endpoint, version: version, path: "/users", auth: "UserToken")

    expect(endpoint.reload.auth_method.kind).to eq("bearer")
  end

  it "answers with nothing for an endpoint that declares no auth" do
    endpoint = FactoryBot.create(:endpoint, version: version, path: "/users", auth: "")

    expect(endpoint.reload.auth_method).to be_nil
  end
end
