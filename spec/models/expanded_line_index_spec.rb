require "rails_helper"

describe ExpandedLineIndex, type: :model do
  let(:version) { Version.new }
  let(:user_entity) { Entity.new(name: "User", root: "{id:number,email:string,name:string}", version: version) }
  let(:parser) { JSONSchemaParser.new([ user_entity ]) }

  def indexes(lines, entities = [ user_entity ])
    described_class.new(lines, entities).to_a
  end

  it "numbers a tree without entity references by position" do
    value = parser.parse_value("{total:number}")
    expect(indexes(value.to_diff(:added))).to eq([ 0, 1, 2 ])
  end

  it "jumps past the rows a collapsed entity reference stands for" do
    value = parser.parse_value("{total:number,items:[User]}")
    expect(indexes(value.to_diff(:added))).to eq([ 0, 1, 2, 3, 4, 9, 10 ])
  end

  it "counts the label row a named entity reference gains when expanded" do
    value = parser.parse_value("{owner:User,count:number}")
    expect(indexes(value.to_diff(:no_change))).to eq([ 0, 1, 7, 8 ])
  end

  it "consumes a single row for an entity whose root is a primitive" do
    tag_entity = Entity.new(name: "Tag", root: "string", version: version)
    value = JSONSchemaParser.new([ tag_entity ]).parse_value("{tag:Tag,count:number}")
    expect(indexes(value.to_diff(:no_change), [ tag_entity ])).to eq([ 0, 1, 2, 3 ])
  end

  it "numbers a bare entity root as a single row" do
    value = parser.parse_value("User")
    expect(indexes(value.to_diff(:added))).to eq([ 0 ])
  end

  it "spends no index on blank alignment rows" do
    before = parser.parse_value("{total:number,legacy:string,items:[User]}")
    after = parser.parse_value("{total:number,items:[User]}")

    expect(indexes(Diff::FromValues.new(before, after).after)).to eq([ 0, 1, 2, 3, 4, 9, nil, 10 ])
  end

  it "counts a reference nested inside a reference, since expansion goes all the way down" do
    nesting = Version.new
    address = nesting.entities.build(name: "Address", root: "{city:string}")
    customer = nesting.entities.build(name: "Customer", root: "{name:string,address:Address}")
    entities = [ address, customer ]
    value = JSONSchemaParser.new(entities).parse_value("{owner:Customer,count:number}")

    expect(indexes(value.to_diff(:no_change), entities)).to eq([ 0, 1, 9, 10 ])
  end

  it "uses the current size of an entity whose root gained a field" do
    new_user = Entity.new(name: "User", root: "{id:number,email:string,name:string,avatar_url:string}", version: version)
    value = JSONSchemaParser.new([ new_user ]).parse_value("{total:number,items:[User]}")

    expect(indexes(value.to_diff(:no_change), [ new_user ])).to eq([ 0, 1, 2, 3, 4, 10, 11 ])
  end
end
