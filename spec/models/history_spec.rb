require "rails_helper"

describe History, "entity milestones" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }

  def version(name, order, roots)
    candidate = FactoryBot.create(:candidate, name: "rc#{order}", project: project, order: order)
    FactoryBot.create(:version, project: project, candidate: candidate, name: name, order: order).tap do |version|
      roots.each { |entity_name, root| FactoryBot.create(:entity, version: version, name: entity_name, root: root) }
    end
  end

  def milestones_for(entity_name)
    latest = project.versions.order(:order).reverse.find { |v| v.entities.find_by(name: entity_name) }
    entity = latest.entities.find_by(name: entity_name)
    History.for_entity(project, entity).milestones.map { |m| [ m.version.name, m.kind ] }
  end

  it "reports the version an entity first appeared in as an addition" do
    version("v1", 1, "User" => "{id:number}")

    expect(milestones_for("User")).to eq([ [ "v1", :added ] ])
  end

  it "says nothing about versions that left the entity alone" do
    version("v1", 1, "User" => "{id:number}")
    version("v2", 2, "User" => "{id:number}")
    version("v3", 3, "User" => "{id:number}")
    version("v4", 4, "User" => "{id:number,email:string}")

    expect(milestones_for("User")).to eq([ [ "v4", :changed ], [ "v1", :added ] ])
  end

  it "treats a reordered object as no change at all" do
    version("v1", 1, "User" => "{id:number,email:string}")
    version("v2", 2, "User" => "{email:string,id:number}")

    expect(milestones_for("User")).to eq([ [ "v1", :added ] ])
  end

  it "diffs a change against the version that last touched the entity" do
    version("v1", 1, "User" => "{id:number}")
    version("v2", 2, "User" => "{id:number}")
    version("v3", 3, "User" => "{id:number,email:string}")

    changed = History.for_entity(project, project.versions.find_by(name: "v3").entities.find_by(name: "User")).milestones.first

    expect(changed.kind).to eq(:changed)
    expect(changed.before.version.name).to eq("v1")
    expect(changed.after.version.name).to eq("v3")
  end

  it "reports a removal against the last version that touched the entity, not the last that carried it" do
    version("v1", 1, "User" => "{id:number}")
    version("v2", 2, "User" => "{id:number}")
    version("v3", 3, {})

    removed = History.for_entity(project, project.versions.find_by(name: "v2").entities.find_by(name: "User")).milestones

    expect(removed.map { |m| [ m.version.name, m.kind ] }).to eq([ [ "v3", :removed ], [ "v1", :added ] ])
    expect(removed.first.after).to be_nil
    expect(removed.first.before.version.name).to eq("v1")
  end

  it "reads a re-appearance after a removal as an addition, not a change" do
    version("v1", 1, "User" => "{id:number}")
    version("v2", 2, {})
    version("v3", 3, "User" => "{id:number}")

    expect(milestones_for("User")).to eq([ [ "v3", :added ], [ "v2", :removed ], [ "v1", :added ] ])
  end

  it "counts a change in a referenced entity as a milestone for the referencing one" do
    version("v1", 1, "Address" => "{city:string}", "User" => "{address:Address}")
    version("v2", 2, "Address" => "{city:string,zip:string}", "User" => "{address:Address}")

    expect(milestones_for("User")).to eq([ [ "v2", :changed ], [ "v1", :added ] ])
  end

  it "has nothing to report for an entity no published version carries" do
    version("v1", 1, "User" => "{id:number}")
    candidate = FactoryBot.create(:candidate, name: "open", project: project, order: 9)
    unpublished = FactoryBot.create(:version, project: nil, candidate: candidate, name: "rc-v1", order: 1)
    fresh = FactoryBot.create(:entity, version: unpublished, name: "Invoice", root: "{id:number}")

    expect(History.for_entity(project, fresh).milestones).to be_empty
  end
end

describe History, "endpoint milestones" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }

  def version(name, order)
    candidate = FactoryBot.create(:candidate, name: "rc#{order}", project: project, order: order)
    FactoryBot.create(:version, project: project, candidate: candidate, name: name, order: order)
  end

  def milestones_for(endpoint)
    History.for_endpoint(project, endpoint).milestones.map { |m| [ m.version.name, m.kind ] }
  end

  it "tracks an endpoint across versions by verb and path" do
    v1 = version("v1", 1)
    v2 = version("v2", 2)
    FactoryBot.create(:endpoint, version: v1, path: "/users", http_verb: "verb_get", input: "")
    latest = FactoryBot.create(:endpoint, version: v2, path: "/users", http_verb: "verb_get", input: "")

    expect(milestones_for(latest)).to eq([ [ "v1", :added ] ])
  end

  it "does not confuse two verbs on one path" do
    v1 = version("v1", 1)
    v2 = version("v2", 2)
    FactoryBot.create(:endpoint, version: v1, path: "/users", http_verb: "verb_get", input: "")
    FactoryBot.create(:endpoint, version: v2, path: "/users", http_verb: "verb_get", input: "")
    posted = FactoryBot.create(:endpoint, version: v2, path: "/users", http_verb: "verb_post", input: "{name:string}")

    expect(milestones_for(posted)).to eq([ [ "v2", :added ] ])
  end

  it "follows an endpoint through a param rename, and calls it a change" do
    v1 = version("v1", 1)
    v2 = version("v2", 2)
    FactoryBot.create(:endpoint, version: v1, path: "/users/:id", http_verb: "verb_get", input: "")
    renamed = FactoryBot.create(:endpoint, version: v2, path: "/users/:userId", http_verb: "verb_get", input: "")

    expect(milestones_for(renamed)).to eq([ [ "v2", :changed ], [ "v1", :added ] ])
  end

  it "notices a changed response body" do
    v1 = version("v1", 1)
    v2 = version("v2", 2)
    before = FactoryBot.create(:endpoint, version: v1, path: "/users", http_verb: "verb_get", input: "")
    FactoryBot.create(:response, endpoint: before, code: 200, output: "{id:number}")
    after = FactoryBot.create(:endpoint, version: v2, path: "/users", http_verb: "verb_get", input: "")
    FactoryBot.create(:response, endpoint: after, code: 200, output: "{id:number,name:string}")

    expect(milestones_for(after)).to eq([ [ "v2", :changed ], [ "v1", :added ] ])
  end
end
