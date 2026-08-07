class JSONSchemaParser
  OPENING_BRACKETS = [ "{", "[", "(" ].freeze
  CLOSING_BRACKETS = [ "}", "]", ")" ].freeze
  OPTIONAL_SUFFIX = "?".freeze

  def initialize(valid_entities = [])
    @valid_entities = valid_entities
  end

  def parse_whole_value(raw_value)
    return Node::Nothing.new if raw_value.empty?

    parse_value(raw_value)
  end

  def parse_value(raw_value)
    value = raw_value.gsub(/\s+/, "")
    raise RuntimeError.new("Empty value: only a whole value may be empty") if value.empty?

    if value.start_with? "string"
      Node::Primitive.new(kind: "string")
    elsif value.start_with? "number"
      Node::Primitive.new(kind: "number")
    elsif value.start_with? "boolean"
      Node::Primitive.new(kind: "boolean")
    elsif value.start_with? "null"
      Node::Primitive.new(kind: "null")
    elsif value[0] == "{"
      parse_object(value)
    elsif value[0] == "["
      parse_array(value)
    elsif value[0] == "("
      parse_one_of(value)
    else
      parse_entity(value)
    end
  end

  def parse_object(str)
    root = Node::Object.new
    split_by_comma(str[1...-1]).each do |raw_name, raw_value|
      optional = raw_name.end_with?(OPTIONAL_SUFFIX)
      root.object_attributes << Node::ObjectAttribute.new(
        name: optional ? raw_name.delete_suffix(OPTIONAL_SUFFIX) : raw_name,
        value: parse_value(raw_value),
        optional: optional
      )
    end
    root
  end

  def parse_array(str)
    root = Node::Array.new
    new_str = str[1...-1]
    inside = parse_value(new_str)
    root.value = inside
    root
  end

  def parse_one_of(str)
    Node::OneOf.new(branches: split_by_pipe(str[1...-1]).map { |branch| parse_value(branch) })
  end

  def split_by_pipe(str)
    ret = []
    deep = 0
    tmp = ""

    str.chars.each do |char|
      if char == "|" && deep.zero?
        ret << tmp
        tmp = ""
      else
        deep += 1 if OPENING_BRACKETS.include?(char)
        deep -= 1 if CLOSING_BRACKETS.include?(char)
        tmp += char
      end
    end

    ret << tmp
    ret
  end

  def parse_entity(value)
    valid_entity = @valid_entities.select { |e| e.name == value }.first
    raise RuntimeError.new("Unknown value: #{value}") if valid_entity.nil?

    Node::Entity.new(entity: valid_entity)
  end

  def strip_name(str)
    str.slice(str.index("{")..-1)
  end

  def split_by_comma(str)
    return [] if str.empty?

    ret = []
    deep = 0
    tmp = ""

    str.chars.each do |char|
      if char == ","
        if deep === 0
          splitted = tmp.split(":")
          rest = tmp[(splitted[0].length + 1)..-1]
          ret << [ splitted[0], rest ]
          tmp = ""
        else
          tmp += char
        end

      elsif char == "{"
        deep += 1
        tmp += char
      elsif char == "}"
        deep -= 1
        tmp += char
      else
        tmp += char
      end
    end

    splitted = tmp.split(":")
    rest = tmp[(splitted[0].length + 1)..-1]
    ret << [ splitted[0], rest ]
    ret
  end
end
