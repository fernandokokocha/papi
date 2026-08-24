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

  def entity_edit(op, id, removed: [])
    blocks = {
      "entity_root_0" => { field: "version[entities_attributes][0][root]", name: "Order", root: "{id:number,customer:Customer}" },
      "entity_root_1" => { field: "version[entities_attributes][1][root]", name: "Customer", root: "{id:string}" }
    }
    removed.each { |block_id| blocks[block_id][:removed] = "1" }

    post schema_edit_path, params: { blocks: blocks, id: id, op: op }
  end

  def form_fields
    Nokogiri::HTML5.fragment(response.body).css("input[type=hidden]").to_h { |input| [ input["name"], input["value"] ] }
  end

  # A removed entity is one the new version is not told about, so its card
  # stops writing into version[entities_attributes] — and it keeps writing into
  # the ops form, which is the only reason it can come back.
  it "stops submitting a removed entity to the version, and keeps submitting it to itself" do
    entity_edit("remove_entity", "entity_root_0")

    expect(turbo_actions).to eq([ [ "replace", "entities" ] ])
    expect(form_fields).not_to include("version[entities_attributes][0][name]", "version[entities_attributes][0][root]")
    expect(form_fields["blocks[entity_root_0][root]"]).to eq("{id:number,customer:Customer}")
    expect(form_fields["blocks[entity_root_0][removed]"]).to eq("1")
  end

  it "gives a removed entity back the fields the version reads" do
    entity_edit("restore_entity", "entity_root_0", removed: [ "entity_root_0" ])

    expect(form_fields["version[entities_attributes][0][name]"]).to eq("Order")
    expect(form_fields["version[entities_attributes][0][root]"]).to eq("{id:number,customer:Customer}")
    expect(form_fields).not_to include("blocks[entity_root_0][removed]")
  end

  # Turbo Drive is off, so a submitter outside a data-turbo="true" container
  # navigates the browser to the stream instead of applying it.
  it "puts the card's own controls inside a Turbo container too" do
    entity_edit("remove_entity", "entity_root_0")

    page = Nokogiri::HTML5.fragment(response.body)
    controls = page.css("button[formaction*='entity']")
    expect(controls).to be_any
    expect(controls).to all(satisfy { |control| control.ancestors("[data-turbo='true']").any? })
  end

  it "takes a removed name out of the types the others may still choose" do
    entity_edit("remove_entity", "entity_root_0")

    expect(types_in("entity_root_1")).not_to include("Order")
  end

  # Removing Customer while Order points at it would leave a reference to a
  # name the parser no longer knows, and withholding the control is the whole
  # enforcement.
  it "offers no remove control on an entity another entity references" do
    entity_edit("restore_entity", "entity_root_0", removed: [ "entity_root_0" ])

    removable = Nokogiri::HTML5.fragment(response.body).css("button[title='Remove entity']")
      .map { |button| button["formaction"][/id=(\w+)/, 1] }
    expect(removable).to eq([ "entity_root_0" ])
  end

  def add_entity(name, blocks_removed: [])
    blocks = {
      "entity_root_0" => { field: "version[entities_attributes][0][root]", name: "Order", root: "{id:number,customer:Customer}" },
      "entity_root_1" => { field: "version[entities_attributes][1][root]", name: "Customer", root: "{id:string}" }
    }
    blocks_removed.each { |block_id| blocks[block_id][:removed] = "1" }

    post schema_edit_path, params: { blocks: blocks, op: "add_entity", new_entity: name }
  end

  it "gives a new entity a slot of its own, a string to start from, and the flag that says it is new" do
    add_entity("Invoice")

    expect(turbo_actions).to eq([ [ "replace", "entities" ] ])
    expect(form_fields["version[entities_attributes][2][name]"]).to eq("Invoice")
    expect(form_fields["version[entities_attributes][2][root]"]).to eq("string")
    expect(form_fields["blocks[entity_root_2][added]"]).to eq("1")
  end

  it "offers the new name to the entities that may reference it" do
    add_entity("Invoice")

    expect(types_in("entity_root_1")).to include("Invoice")
  end

  it "refuses a name that does not start with an uppercase letter, and hands the typing back" do
    add_entity("invoice")

    expect(response.body).to include("An entity name must start with an uppercase letter")
    expect(form_fields).not_to include("version[entities_attributes][2][name]")
    expect(Nokogiri::HTML5.fragment(response.body).at_css("input[name='new_entity']")["value"]).to eq("invoice")
  end

  it "refuses a name the form already has" do
    add_entity("Customer")

    expect(response.body).to include("This entity already exists")
  end

  # The name is free again the moment the entity holding it is removed, which
  # is how an entity is replaced rather than edited.
  it "lets a removed name be taken again" do
    add_entity("Customer", blocks_removed: [ "entity_root_1" ])

    expect(response.body).not_to include("This entity already exists")
    expect(form_fields["version[entities_attributes][2][name]"]).to eq("Customer")
  end

  # A new entity was never in the base version, so there is nothing for it to
  # read as removed against — its control discards the slot outright.
  it "discards a new entity instead of marking it removed" do
    post schema_edit_path, params: {
      blocks: {
        "entity_root_0" => { field: "version[entities_attributes][0][root]", name: "Order", root: "{id:number}" },
        "entity_root_1" => { field: "version[entities_attributes][1][root]", name: "Invoice", root: "string", added: "1" }
      },
      id: "entity_root_1", op: "drop_entity"
    }

    expect(form_fields.keys.grep(/entities_attributes/)).to eq([ "version[entities_attributes][0][name]", "version[entities_attributes][0][root]" ])
  end

  # Dropping a slot moves every slot after it, and a name field left at the old
  # number would write itself into a record the root field never reaches.
  it "renumbers the slots the version reads once the set changes" do
    post schema_edit_path, params: {
      blocks: {
        "entity_root_0" => { field: "version[entities_attributes][0][root]", name: "Draft", root: "string", added: "1" },
        "entity_root_1" => { field: "version[entities_attributes][1][root]", name: "Order", root: "{id:number}" }
      },
      id: "entity_root_0", op: "drop_entity"
    }

    expect(form_fields["version[entities_attributes][0][name]"]).to eq("Order")
    expect(form_fields["version[entities_attributes][0][root]"]).to eq("{id:number}")
    expect(form_fields).not_to include("version[entities_attributes][1][name]")
  end

  # Order had to go first — Customer was unremovable while Order pointed at it
  # — so by now the reference on the removed card names an entity the version
  # no longer has.
  it "reads a removed entity that points at another removed one" do
    entity_edit("remove_entity", "entity_root_1", removed: [ "entity_root_0" ])

    expect(form_fields["blocks[entity_root_0][root]"]).to eq("{id:number,customer:Customer}")
  end

  def auth_edit(op, index = nil, removed: [], added: [], new_auth_method: nil)
    auth_methods = {
      "0" => { name: "UserToken", kind: "bearer", note: "A token from POST /session." },
      "1" => { name: "AdminBasic", kind: "basic", note: "Operator credentials." }
    }
    removed.each { |position| auth_methods[position][:removed] = "1" }
    added.each { |position| auth_methods[position][:added] = "1" }

    post schema_edit_path, params: { auth_methods: auth_methods, index: index, op: op, new_auth_method: new_auth_method }.compact
  end

  # A removed auth method is one the new version is not told about, so its card
  # stops writing into version[auth_methods_attributes] — and it keeps writing
  # into the ops form, which is the only reason it can come back.
  it "stops submitting a removed auth method to the version, and keeps submitting it to itself" do
    auth_edit("remove_auth_method", 0)

    expect(turbo_actions).to eq([ [ "replace", "auth_methods" ] ])
    expect(form_fields).not_to include("version[auth_methods_attributes][0][name]", "version[auth_methods_attributes][0][kind]")
    expect(form_fields["auth_methods[0][note]"]).to eq("A token from POST /session.")
    expect(form_fields["auth_methods[0][removed]"]).to eq("1")
  end

  it "gives a removed auth method back the fields the version reads" do
    auth_edit("restore_auth_method", 0, removed: [ "0" ])

    expect(form_fields["version[auth_methods_attributes][0][name]"]).to eq("UserToken")
    expect(form_fields["version[auth_methods_attributes][0][kind]"]).to eq("bearer")
    expect(form_fields).not_to include("auth_methods[0][removed]")
  end

  it "gives a new auth method a bearer to start from, and the flag that says it is new" do
    auth_edit("add_auth_method", new_auth_method: "ServiceKey")

    expect(form_fields["version[auth_methods_attributes][2][name]"]).to eq("ServiceKey")
    expect(form_fields["version[auth_methods_attributes][2][kind]"]).to eq("bearer")
    expect(form_fields["version[auth_methods_attributes][2][note]"]).to eq("")
    expect(form_fields["auth_methods[2][added]"]).to eq("1")
  end

  it "refuses a nameless auth method, and refuses a name the form already has" do
    auth_edit("add_auth_method", new_auth_method: "")
    expect(response.body).to include("An auth method needs a name")

    auth_edit("add_auth_method", new_auth_method: "AdminBasic")
    expect(response.body).to include("This auth method already exists")
    expect(form_fields).not_to include("version[auth_methods_attributes][2][name]")
  end

  it "lets a removed name be taken again" do
    auth_edit("add_auth_method", removed: [ "1" ], new_auth_method: "AdminBasic")

    expect(form_fields["version[auth_methods_attributes][2][name]"]).to eq("AdminBasic")
  end

  it "discards a new auth method instead of marking it removed" do
    auth_edit("drop_auth_method", 1, added: [ "1" ])

    expect(form_fields.keys.grep(/auth_methods_attributes/)).to eq([
      "version[auth_methods_attributes][0][name]",
      "version[auth_methods_attributes][0][kind]",
      "version[auth_methods_attributes][0][note]"
    ])
  end

  # A project's first candidate holds neither, so the form submits no blocks
  # and no auth methods at all.
  it "adds the first entity and the first auth method to a form that holds none" do
    post schema_edit_path, params: { op: "add_entity", new_entity: "Customer" }
    expect(form_fields["version[entities_attributes][0][name]"]).to eq("Customer")

    post schema_edit_path, params: { op: "add_auth_method", new_auth_method: "UserToken" }
    expect(form_fields["version[auth_methods_attributes][0][name]"]).to eq("UserToken")
  end
end
