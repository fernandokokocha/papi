require "rails_helper"

describe SchemaPathIndex do
  let(:version) { Version.new }
  let(:attachment) do
    Entity.new(name: "Attachment", root: "{id:number,url:string}", version: version)
  end
  let(:parser) { JSONSchemaParser.new([ attachment ]) }

  def paths(schema, expanded: false)
    value = parser.parse_whole_value(schema)
    value = value.expand if expanded
    lines = value.to_diff(:no_change)
    described_class.new(lines).to_a.each_with_index.map { |path, row| [ lines.lines[row].whole_line, path ] }
  end

  it "names each attribute of a flat object" do
    expect(paths("{id:number,email:string}")).to eq([
      [ "{", [] ], [ "id: number", [ "id" ] ], [ "email: string", [ "email" ] ], [ "}", [] ]
    ])
  end

  it "gives a nested object's label and brace the same path" do
    expect(paths("{customer:{city:string}}")).to eq([
      [ "{", [] ],
      [ "customer:", [ "customer" ] ],
      [ "{", [ "customer" ] ],
      [ "city: string", [ "customer", "city" ] ],
      [ "}", [ "customer" ] ],
      [ "}", [] ]
    ])
  end

  it "addresses an array element as nil, the way findByPath does" do
    expect(paths("{items:[{sku:string}]}")).to eq([
      [ "{", [] ],
      [ "items:", [ "items" ] ],
      [ "[", [ "items" ] ],
      [ "{", [ "items", nil ] ],
      [ "sku: string", [ "items", nil, "sku" ] ],
      [ "}", [ "items", nil ] ],
      [ "]", [ "items" ] ],
      [ "}", [] ]
    ])
  end

  it "numbers one-of branches from zero" do
    expect(paths("{name:(string|null)}")).to eq([
      [ "{", [] ],
      [ "name:", [ "name" ] ],
      [ "(", [ "name" ] ],
      [ "string", [ "name", 0 ] ],
      [ "null", [ "name", 1 ] ],
      [ ")", [ "name" ] ],
      [ "}", [] ]
    ])
  end

  it "strips the optional marker, so a note survives toggling it" do
    expect(paths("{details?:string}")).to eq([
      [ "{", [] ], [ "details?: string", [ "details" ] ], [ "}", [] ]
    ])
  end

  it "keeps a collapsed reference addressed by its attribute" do
    expect(paths("{file:Attachment}")).to eq([
      [ "{", [] ], [ "file: Attachment", [ "file" ] ], [ "}", [] ]
    ])
  end

  # Line addressing needed a whole mapping for this; paths get it for nothing,
  # because expansion only ever changes what sits below a reference's own line.
  it "leaves the attribute's path alone when the reference is expanded" do
    expanded = paths("{file:Attachment}", expanded: true)

    expect(expanded.first(3)).to eq([
      [ "{", [] ], [ "file:", [ "file" ] ], [ "{", [ "file" ] ]
    ])
  end

  it "points a note at the label rather than the brace" do
    lines = parser.parse_whole_value("{customer:{city:string}}").to_diff(:no_change)

    expect(described_class.new(lines).first_row_per_path[[ "customer" ]]).to eq(1)
  end
end
