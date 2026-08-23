require "rails_helper"

describe "Schema edit requests", type: :request do
  let!(:group) { Group.create!(name: "Test group") }
  let!(:user) { User.create!(email_address: "test@example.com", password: "password", group: group) }

  let(:schema) { "{id:number,tags:[string],address?:{street:string},status:(string|null)}" }

  def edit(op, path, value = nil)
    params = {
      blocks: {
        "entity_root_0" => { field: "version[entities_attributes][0][root]", name: "Order", root: schema },
        "entity_root_1" => { field: "version[entities_attributes][1][root]", name: "Customer", root: "{id:string}" }
      },
      id: "entity_root_0", op: op, value: value
    }
    params[:path] = path if path.any?

    post schema_edit_path, params: params
  end

  def edited_schema
    Nokogiri::HTML5.fragment(response.body).at_css("input[name='version[entities_attributes][0][root]']")["value"]
  end

  def branch_remove_controls
    Nokogiri::HTML5.fragment(response.body).css("button[title='Remove']")
      .select { |button| button["formaction"].include?("path%5B%5D=status&path%5B%5D=0") }
  end

  before { sign_in(user) }

  it "replaces the block it was told to, and carries the new schema in its hidden field" do
    edit("add", [ "address" ])

    expect(turbo_actions).to eq([ [ "replace", "entity_root_0" ] ])
    expect(edited_schema).to eq("{id:number,tags:[string],address?:{street:string,new:string},status:(string|null)}")
  end

  it "applies each operation to the node its path names" do
    edit("change_type", [ "id" ], "Customer")
    expect(edited_schema).to eq("{id:Customer,tags:[string],address?:{street:string},status:(string|null)}")

    edit("change_type", [ "tags", "[]" ], "number")
    expect(edited_schema).to eq("{id:number,tags:[number],address?:{street:string},status:(string|null)}")

    edit("rename", [ "address" ], "location")
    expect(edited_schema).to eq("{id:number,tags:[string],location?:{street:string},status:(string|null)}")

    edit("toggle_optional", [ "address" ])
    expect(edited_schema).to eq("{id:number,tags:[string],address:{street:string},status:(string|null)}")

    edit("remove", [ "address", "street" ])
    expect(edited_schema).to eq("{id:number,tags:[string],address?:{},status:(string|null)}")

    edit("add", [ "status" ])
    expect(edited_schema).to eq("{id:number,tags:[string],address?:{street:string},status:(string|null|number)}")
  end

  it "changes the type of the whole schema when the path is empty" do
    edit("change_type", [], "array")

    expect(edited_schema).to eq("[string]")
  end

  it "withholds a branch's type from its siblings" do
    edit("add", [ "status" ])

    first_branch = Nokogiri::HTML5.fragment(response.body).css("select")
      .find { |select| select["data-schema-edit-url-value"].include?("path%5B%5D=status&path%5B%5D=0") }

    expect(first_branch.css("option").map(&:text)).not_to include("null", "number")
  end

  def types_in(id)
    Nokogiri::HTML5.fragment(response.body).css("##{id} select").flat_map { |select| select.css("option").map(&:text) }.uniq
  end

  it "withholds from the answer every name that would close a circle" do
    edit("change_type", [ "id" ], "Customer")

    expect(types_in("entity_root_0")).to include("Customer")
    expect(types_in("entity_root_0")).not_to include("Order")
  end

  # Pointing Order at Customer is what takes Order away from Customer, so the
  # block that was not clicked is the one that has gone wrong.
  it "answers with every block the op moved, not only the one that was clicked" do
    edit("change_type", [ "id" ], "Customer")

    expect(turbo_actions).to eq([ [ "replace", "entity_root_0" ], [ "replace", "entity_root_1" ] ])
    expect(types_in("entity_root_1")).not_to include("Order")
  end

  it "leaves alone the blocks an op does not reach" do
    edit("rename", [ "id" ], "identifier")

    expect(turbo_actions).to eq([ [ "replace", "entity_root_0" ] ])
  end

  # A one-of needs two branches to mean anything, and nothing validates that —
  # withholding the control is the whole enforcement, as it was in the editor
  # this replaces.
  it "offers no remove control on a one-of's branches until there are three" do
    edit("rename", [ "id" ], "identifier")
    expect(branch_remove_controls).to be_empty

    edit("add", [ "status" ])
    expect(branch_remove_controls.size).to eq(1)
  end

  # The whole form is submitted, so the block being edited is the one the op
  # names — not merely the only one there is.
  it "edits the block the op names, leaving its neighbours alone" do
    post schema_edit_path, params: {
      blocks: {
        "entity_root_0" => { field: "version[entities_attributes][0][root]", root: "{id:number}" },
        "entity_root_1" => { field: "version[entities_attributes][1][root]", root: "{total:number}" },
        "entity_root_2" => { field: "version[entities_attributes][2][root]", root: "{label:string}" }
      },
      id: "entity_root_1", op: "add"
    }

    fields = Nokogiri::HTML5.fragment(response.body).css("input[type=hidden]").to_h { |i| [ i["name"], i["value"] ] }
    expect(turbo_actions).to eq([ [ "replace", "entity_root_1" ] ])
    expect(fields["version[entities_attributes][1][root]"]).to eq("{total:number,new:string}")
    expect(fields.keys).not_to include("version[entities_attributes][0][root]")
  end
  # Nothing is remembered between ops: each answer carries the whole schema
  # back into the field the next op reads from, so the browser holds the state
  # and the server stays a function.
  it "accumulates edits through the field it hands back, storing nothing" do
    post schema_edit_path, params: {
      blocks: { "entity_root_0" => { field: "version[entities_attributes][0][root]", root: "{id:number}" } },
      id: "entity_root_0", op: "add"
    }
    expect(edited_schema).to eq("{id:number,new:string}")

    writes = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      writes += 1 if payload[:sql].match?(/\A\s*(INSERT|UPDATE|DELETE)/i)
    end

    post schema_edit_path, params: {
      blocks: { "entity_root_0" => { field: "version[entities_attributes][0][root]", root: edited_schema } },
      id: "entity_root_0", op: "rename", path: [ "new" ], value: "label"
    }

    ActiveSupport::Notifications.unsubscribe(subscriber)

    expect(edited_schema).to eq("{id:number,label:string}")
    expect(writes).to eq(0)
  end
end
