require "rails_helper"

describe Version, "endpoint collisions" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }

  def version_with(*paths)
    FactoryBot.build(:version, project: project, name: "v1").tap do |version|
      paths.each { |path| version.endpoints.build(path: path, http_verb: "verb_get") }
    end
  end

  it "rejects two endpoints a client cannot tell apart" do
    version = version_with("/user/:id", "/user/:user_id")

    expect(version).not_to be_valid
    expect(version.errors[:endpoints]).to eq([ "collide: GET /user/:" ])
  end

  it "rejects two literally identical endpoints" do
    expect(version_with("/user", "/user")).not_to be_valid
  end

  it "accepts endpoints that differ in a literal segment" do
    expect(version_with("/user/:id", "/account/:id")).to be_valid
  end

  it "accepts endpoints that differ in how many params they take" do
    expect(version_with("/user/:id", "/user/:id/posts/:postId")).to be_valid
  end
end

describe Version, "entity reference circles" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }

  def version_with(roots)
    FactoryBot.build(:version, project: project, name: "v1").tap do |version|
      roots.each { |name, root| version.entities.build(name: name, root: root) }
    end
  end

  it "rejects a circle, which would otherwise hang every diff and example" do
    version = version_with("Order" => "{customer:Customer}", "Customer" => "{order:Order}")

    expect(version).not_to be_valid
    expect(version.errors[:entities]).to eq([ "reference each other in a circle: Order → Customer → Order" ])
  end

  it "accepts entities nested in a chain" do
    expect(version_with("Address" => "{city:string}", "Customer" => "{address:Address}")).to be_valid
  end
end

describe Version, "release notes" do
  let(:version) { FactoryBot.create(:version, name: "v1", release_notes: "Adds the search endpoint.") }

  it "starts a duplicate empty, because notes describe one version's change and not the next" do
    copy = version.reload.amoeba_dup

    expect(copy.release_notes).to eq("")
  end

  it "leaves the original's notes alone when the duplicate is saved" do
    copy = version.reload.amoeba_dup
    copy.name = "v2"
    copy.save!

    expect(version.reload.release_notes).to eq("Adds the search endpoint.")
  end
end
