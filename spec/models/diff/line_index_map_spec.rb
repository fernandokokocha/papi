require "rails_helper"

describe Diff::LineIndexMap, type: :model do
  let(:version) { Version.new }
  let(:user_entity) { Entity.new(name: "User", root: "{id:number,email:string,name:string}", version: version) }
  let(:parser) { JSONSchemaParser.new([ user_entity ]) }

  def map_for(rendered, expanded)
    described_class.new(rendered, expanded).to_a
  end

  it "is the identity for a tree without entity references" do
    value = parser.parse_value("{total:number}")
    expect(map_for(value.to_diff(:added), value.expand.to_diff(:added))).to eq([ 0, 1, 2 ])
  end

  it "maps rows past a collapsed entity reference inside an array" do
    value = parser.parse_value("{total:number,items:[User]}")
    expect(map_for(value.to_diff(:added), value.expand.to_diff(:added))).to eq([ 0, 1, 2, 3, 4, 9, 10 ])
  end

  it "maps a labeled entity attribute to its expanded label row" do
    value = parser.parse_value("{owner:User,count:number}")
    expect(map_for(value.to_diff(:no_change), value.expand.to_diff(:no_change))).to eq([ 0, 1, 7, 8 ])
  end

  it "consumes a single expanded row for an entity with a primitive root" do
    tag_entity = Entity.new(name: "Tag", root: "string", version: version)
    tag_parser = JSONSchemaParser.new([ tag_entity ])
    value = tag_parser.parse_value("{tag:Tag,count:number}")
    expect(map_for(value.to_diff(:no_change), value.expand.to_diff(:no_change))).to eq([ 0, 1, 2, 3 ])
  end

  it "maps a bare entity root to the first row of its expansion" do
    value = parser.parse_value("User")
    expect(map_for(value.to_diff(:added), value.expand.to_diff(:added))).to eq([ 0 ])
  end

  it "maps blank alignment rows to nil and stays aligned past them" do
    before = parser.parse_value("{total:number,legacy:string,items:[User]}")
    after = parser.parse_value("{total:number,items:[User]}")
    rendered = Diff::FromValues.new(before, after).after
    expanded = Diff::FromValues.new(before.expand, after.expand).after
    expect(map_for(rendered, expanded)).to eq([ 0, 1, 2, 3, 4, 9, nil, 11 ])
  end

  it "maps a type_changed entity reference whose root gained a field" do
    old_user = Entity.new(name: "User", root: "{id:number,email:string,name:string}", version: version)
    new_user = Entity.new(name: "User", root: "{id:number,email:string,name:string,avatar_url:string}", version: version)
    before = JSONSchemaParser.new([ old_user ]).parse_value("{total:number,items:[User]}")
    after = JSONSchemaParser.new([ new_user ]).parse_value("{total:number,items:[User]}")
    rendered = Diff::FromValues.new(before, after).after
    expanded = Diff::FromValues.new(before.expand, after.expand).after
    expect(map_for(rendered, expanded)).to eq([ 0, 1, 2, 3, 4, 10, 11 ])
  end
end
