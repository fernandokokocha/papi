require "rails_helper"

describe EntityReferences, "#cycle" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }
  let!(:version) { FactoryBot.create(:version, project: project, name: "v1") }

  def entities_with(roots)
    roots.map { |name, root| version.entities.build(name: name, root: root) }
  end

  it "finds nothing when no entity names another" do
    entities = entities_with("Customer" => "{id:string}", "Order" => "{total:number}")

    expect(EntityReferences.new(entities).cycle).to be_nil
  end

  it "finds nothing in a chain" do
    entities = entities_with(
      "Address" => "{city:string}",
      "Customer" => "{address:Address}",
      "Order" => "{customer:Customer}"
    )

    expect(EntityReferences.new(entities).cycle).to be_nil
  end

  it "finds nothing when two entities share a reference" do
    entities = entities_with(
      "Address" => "{city:string}",
      "Customer" => "{address:Address}",
      "Warehouse" => "{address:Address}"
    )

    expect(EntityReferences.new(entities).cycle).to be_nil
  end

  it "finds an entity that names itself" do
    entities = entities_with("Node" => "{parent:Node}")

    expect(EntityReferences.new(entities).cycle).to eq(%w[Node Node])
  end

  it "finds a pair that name each other" do
    entities = entities_with("Order" => "{customer:Customer}", "Customer" => "{order:Order}")

    expect(EntityReferences.new(entities).cycle).to eq(%w[Order Customer Order])
  end

  it "finds a circle reached through three entities" do
    entities = entities_with(
      "A" => "{b:B}",
      "B" => "{c:C}",
      "C" => "{a:A}"
    )

    expect(EntityReferences.new(entities).cycle).to eq(%w[A B C A])
  end

  it "finds a circle a clean entity points into" do
    entities = entities_with(
      "Root" => "{a:A}",
      "A" => "{b:B}",
      "B" => "{a:A}"
    )

    expect(EntityReferences.new(entities).cycle).to eq(%w[A B A])
  end

  it "looks through arrays and unions" do
    entities = entities_with(
      "Order" => "{lines:[LineItem]}",
      "LineItem" => "{parent:(Order|null)}"
    )

    expect(EntityReferences.new(entities).cycle).to eq(%w[Order LineItem Order])
  end

  it "ignores an entity with no root" do
    entities = entities_with("Empty" => "", "Order" => "{total:number}")

    expect(EntityReferences.new(entities).cycle).to be_nil
  end
end
