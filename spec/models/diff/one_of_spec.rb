require "rails_helper"

describe "OneOf diffs", type: :model do
  def markers = { no_change: ".", added: "+", removed: "-", type_changed: "~", blank: nil }

  def entity(name, root) = FakeEntity.new(name, root)

  def default_entities = [ entity("Resource", "{a:string}"), entity("Other", "{a:string}") ]

  def parse(source, entities) = JSONSchemaParser.new(entities).parse_value(source)

  def cell(line)
    return "" if line.change == :blank
    "#{markers[line.change]} #{'  ' * line.indent}#{line.whole_line}"
  end

  def diff(before, after, before_entities: default_entities, after_entities: default_entities)
    lines = Diff::FromValues.new(parse(before, before_entities), parse(after, after_entities))
    lines.before.lines.zip(lines.after.lines).map { |b, a|
      "#{cell(b).ljust(28)}#{cell(a)}".rstrip
    }.join("\n") + "\n"
  end

  context "widening" do
    it "appends a branch" do
      expect(diff("(string|number)", "(string|number|boolean)")).to eq(<<~DIFF)
        . (                         . (
        .   string                  .   string
        .   number                  .   number
                                    +   boolean
        . )                         . )
      DIFF
    end

    it "inserts a branch at the front" do
      expect(diff("(string|number)", "(boolean|string|number)")).to eq(<<~DIFF)
        . (                         . (
        ~   string                  ~   boolean
        ~   number                  ~   string
                                    +   number
        . )                         . )
      DIFF
    end
  end

  context "narrowing" do
    it "removes the last branch" do
      expect(diff("(string|number|boolean)", "(string|number)")).to eq(<<~DIFF)
        . (                         . (
        .   string                  .   string
        .   number                  .   number
        -   boolean
        . )                         . )
      DIFF
    end

    it "removes a branch from the middle" do
      expect(diff("(string|number|boolean)", "(string|boolean)")).to eq(<<~DIFF)
        . (                         . (
        .   string                  .   string
        ~   number                  ~   boolean
        -   boolean
        . )                         . )
      DIFF
    end
  end

  context "same arity" do
    it "reports nothing for an unchanged union" do
      expect(diff("(string|number)", "(string|number)")).to eq(<<~DIFF)
        . (                         . (
        .   string                  .   string
        .   number                  .   number
        . )                         . )
      DIFF
    end

    it "reports a reorder as two changed branches" do
      expect(diff("(string|number)", "(number|string)")).to eq(<<~DIFF)
        . (                         . (
        ~   string                  ~   number
        ~   number                  ~   string
        . )                         . )
      DIFF
    end

    it "swaps the last branch" do
      expect(diff("(string|number)", "(string|boolean)")).to eq(<<~DIFF)
        . (                         . (
        .   string                  .   string
        ~   number                  ~   boolean
        . )                         . )
      DIFF
    end
  end

  context "nullability" do
    it "reports making a field nullable as a change" do
      expect(diff("boolean", "(boolean|null)")).to eq(<<~DIFF)
        ~ boolean                   ~ (
                                    ~   boolean
                                    ~   null
                                    ~ )
      DIFF
    end

    it "reports making a field non-nullable as a change" do
      expect(diff("(boolean|null)", "boolean")).to eq(<<~DIFF)
        ~ (                         ~ boolean
        ~   boolean
        ~   null
        ~ )
      DIFF
    end

    it "reports a type swap under an unchanged null branch" do
      expect(diff("(string|null)", "(number|null)")).to eq(<<~DIFF)
        . (                         . (
        ~   string                  ~   number
        .   null                    .   null
        . )                         . )
      DIFF
    end
  end

  context "entity branches" do
    it "reports nothing when the entity and its root are unchanged" do
      expect(diff("(Resource|number)", "(Resource|number)")).to eq(<<~DIFF)
        . (                         . (
        .   Resource                .   Resource
        .   number                  .   number
        . )                         . )
      DIFF
    end

    it "reports a change when the entity kept its name but its root drifted" do
      expect(diff("(Resource|number)", "(Resource|number)",
                  after_entities: [ entity("Resource", "{a:string,b:number}") ])).to eq(<<~DIFF)
        . (                         . (
        ~   Resource                ~   Resource
        .   number                  .   number
        . )                         . )
      DIFF
    end

    it "reports a change when the branch points at a different entity" do
      expect(diff("(Resource|number)", "(Other|number)")).to eq(<<~DIFF)
        . (                         . (
        ~   Resource                ~   Other
        .   number                  .   number
        . )                         . )
      DIFF
    end
  end

  context "recursing into a branch" do
    it "diffs inside an object branch" do
      expect(diff("({a:string}|number)", "({a:string,b:number}|number)")).to eq(<<~DIFF)
        . (                         . (
        .   {                       .   {
        .     a: string             .     a: string
                                    +     b: number
        .   }                       .   }
        .   number                  .   number
        . )                         . )
      DIFF
    end

    it "diffs inside the first of two object branches" do
      expect(diff("({id:string}|{error:string})", "({id:string,name:string}|{error:string})")).to eq(<<~DIFF)
        . (                         . (
        .   {                       .   {
        .     id: string            .     id: string
                                    +     name: string
        .   }                       .   }
        .   {                       .   {
        .     error: string         .     error: string
        .   }                       .   }
        . )                         . )
      DIFF
    end

    it "diffs inside an array branch" do
      expect(diff("([string]|number)", "([boolean]|number)")).to eq(<<~DIFF)
        . (                         . (
        .   [                       .   [
        ~     string                ~     boolean
        .   ]                       .   ]
        .   number                  .   number
        . )                         . )
      DIFF
    end
  end

  context "changing to and from a union" do
    it "collapses a union to a primitive" do
      expect(diff("(string|number)", "string")).to eq(<<~DIFF)
        ~ (                         ~ string
        ~   string
        ~   number
        ~ )
      DIFF
    end

    it "widens a primitive into a union" do
      expect(diff("string", "(string|number)")).to eq(<<~DIFF)
        ~ string                    ~ (
                                    ~   string
                                    ~   number
                                    ~ )
      DIFF
    end
  end

  context "nested under an attribute" do
    it "diffs a union that is an object attribute" do
      expect(diff("{a:(string|number)}", "{a:(string|boolean)}")).to eq(<<~DIFF)
        . {                         . {
        .   a:                      .   a:
        .   (                       .   (
        .     string                .     string
        ~     number                ~     boolean
        .   )                       .   )
        . }                         . }
      DIFF
    end
  end
end
