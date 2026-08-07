require "rails_helper"

describe Version::CategorizeByName do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }
  let!(:v1) { FactoryBot.create(:version, project: project, name: "v1") }
  let!(:v2) { FactoryBot.create(:version, project: project, name: "v2") }

  def categorize(previous, current)
    Version::CategorizeByName.new(previous, current).call
  end

  it "pairs an endpoint whose param was renamed, rather than replacing it" do
    before = FactoryBot.create(:endpoint, version: v1, path: "/user/:id")
    after = FactoryBot.create(:endpoint, version: v2, path: "/user/:user_id")

    result = categorize([ before ], [ after ])

    expect(result).to eq([ after ])
    expect(after.annotation).to eq("changed")
    expect(after.previous).to eq(before)
  end

  it "treats a changed literal segment as a different endpoint" do
    before = FactoryBot.create(:endpoint, version: v1, path: "/user/:id")
    after = FactoryBot.create(:endpoint, version: v2, path: "/account/:id")

    result = categorize([ before ], [ after ])

    expect(result).to match_array([ before, after ])
    expect(after.annotation).to eq("added")
    expect(before.annotation).to eq("removed")
  end

  it "treats a dropped param as a different endpoint" do
    before = FactoryBot.create(:endpoint, version: v1, path: "/user/:id")
    after = FactoryBot.create(:endpoint, version: v2, path: "/user")

    result = categorize([ before ], [ after ])

    expect(after.annotation).to eq("added")
    expect(before.annotation).to eq("removed")
  end

  it "still reports an untouched endpoint as unchanged" do
    before = FactoryBot.create(:endpoint, version: v1, path: "/user/:id", note: "one")
    after = FactoryBot.create(:endpoint, version: v2, path: "/user/:id", note: "one")

    categorize([ before ], [ after ])

    expect(after.annotation).to eq("unchanged")
  end

  it "pairs entities by name" do
    before = FactoryBot.create(:entity, version: v1, name: "User", root: "{id:number}")
    after = FactoryBot.create(:entity, version: v2, name: "User", root: "{id:string}")

    categorize([ before ], [ after ])

    expect(after.annotation).to eq("changed")
  end
end
