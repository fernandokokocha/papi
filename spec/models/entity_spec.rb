require "rails_helper"

describe Entity, "#parsed_root" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }
  let!(:version) { FactoryBot.create(:version, project: project, name: "v1") }

  it "resolves a name that belongs to another entity in the same version" do
    FactoryBot.create(:entity, version: version, name: "Customer", root: "{id:string}")
    order = FactoryBot.create(:entity, version: version, name: "Order", root: "{customer:Customer}")

    referenced = order.reload.parsed_root.object_attributes.first.value

    expect(referenced).to be_a(Node::Entity)
    expect(referenced.entity.name).to eq("Customer")
  end

  it "raises for a name no entity in the version carries" do
    order = FactoryBot.create(:entity, version: version, name: "Order", root: "{customer:Customer}")

    expect { order.reload.parsed_root }.to raise_error(RuntimeError, "Unknown value: Customer")
  end
end

describe Entity, "nested references" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }
  let!(:version) { FactoryBot.create(:version, project: project, name: "v1") }

  it "builds example json through a nested reference" do
    FactoryBot.create(:entity, version: version, name: "Customer", root: "{id:number}")
    FactoryBot.create(:entity, version: version, name: "Order", root: "{customer:Customer}")
    endpoint = FactoryBot.create(:endpoint, version: version, path: "/orders", input: "")
    response = FactoryBot.create(:response, endpoint: endpoint, code: "200", output: "Order")

    expect(response.reload.parsed_output.to_example_json).to eq('{ "customer": { "id": 0 } }')
  end

  it "sees a change made two levels down" do
    FactoryBot.create(:entity, version: version, name: "Customer", root: "{id:number}")
    order = FactoryBot.create(:entity, version: version, name: "Order", root: "{customer:Customer}")

    later = FactoryBot.create(:version, project: project, name: "v2")
    FactoryBot.create(:entity, version: later, name: "Customer", root: "{id:number,vip:boolean}")
    later_order = FactoryBot.create(:entity, version: later, name: "Order", root: "{customer:Customer}")

    expect(later_order.reload.differs_from?(order.reload)).to eq(true)
  end
end

describe Entity, "#parsed_root expanded" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }
  let!(:version) { FactoryBot.create(:version, project: project, name: "v1") }

  it "swaps every reference for its root, however deeply nested" do
    FactoryBot.create(:entity, version: version, name: "Address", root: "{city:string}")
    FactoryBot.create(:entity, version: version, name: "Customer", root: "{address:Address}")
    order = FactoryBot.create(:entity, version: version, name: "Order", root: "{customer:Customer}")

    customer = order.reload.parsed_root(expanded: true).object_attributes.first.value
    address = customer.object_attributes.first.value

    expect(customer).to be_a(Node::Object)
    expect(address).to be_a(Node::Object)
    expect(address.object_attributes.first.value).to be_a(Node::Primitive)
  end
end

describe Entity, "#to_lines" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }
  let!(:version) { FactoryBot.create(:version, project: project, name: "v1") }

  it "renders the rows a reference stands for once expanded, all the way down" do
    FactoryBot.create(:entity, version: version, name: "Address", root: "{city:string}")
    FactoryBot.create(:entity, version: version, name: "Customer", root: "{name:string,address:Address}")
    order = FactoryBot.create(:entity, version: version, name: "Order", root: "{customer:Customer}")

    expect(order.reload.to_lines.map(&:whole_line)).to eq(
      [ "{", "customer:", "{", "name: string", "address:", "{", "city: string", "}", "}", "}" ]
    )
  end
end
