class RootParser
  def parse_value(raw_value)
    value = raw_value.gsub(/\s+/, "")

    if value.start_with? "string"
      PrimitiveNode.new(kind: "string")
    elsif value.start_with? "number"
      PrimitiveNode.new(kind: "number")
    elsif value.start_with? "boolean"
      PrimitiveNode.new(kind: "boolean")
    elsif value[0] == "{"
      parse_object(value)
    elsif value[0] == "["
      parse_array(value)
    else
      raise RuntimeError, "Parsing unknown value type: #{value}"
    end
  end

  def parse_object(str)
    root = ObjectNode.new
    attrs = split_by_comma(str[1...-1])
    attrs.map.with_index do |attr, i|
      value = parse_value(attr[1])
      root.object_attributes.build(name: attr[0], value: value, order: i, parent: root)
    end
    root
  end

  def parse_array(str)
    root = ArrayNode.new
    new_str = str[1...-1]
    inside = parse_value(new_str)
    root.value = inside
    root
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
