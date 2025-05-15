class RootParser
  def parse_object(str)
    root = ObjectNode.new
    attrs = split_by_comma(str[1...-1])
    attrs.map.with_index do |attr, i|
      raw_name = attr.split(":")[0]
      raw_value = attr.split(":")[1]

      raw_name.strip!
      raw_value.strip!
      if raw_value[0] == "{"
        raw_value = strip_name(attr)
        raw_value.strip!
      end

      value = parse_value(raw_value)
      root.object_attributes.build(name: raw_name, value: value, order: i, parent: root)
    end
    root
  end

  def parse_value(raw_value)
    if raw_value == "string"
      PrimitiveNode.new(kind: "string")
    elsif raw_value == "number"
      PrimitiveNode.new(kind: "number")
    elsif raw_value == "boolean"
      PrimitiveNode.new(kind: "boolean")
    else
      parse_object(raw_value)
    end
  end

  def strip_name(str)
    str.slice(str.index("{")..-1)
  end

  def split_by_comma(str)
    ret = []
    s = str.gsub(/\s+/, "")
    while not s.empty?
      splitted = s.split(":")
      name = splitted.shift
      rest = splitted.join(":").split("")
      if rest[0] == "{"
        rest.shift
        deel_level = 1
        value = "{"
        while deel_level > 0
          next_char = rest.shift
          break if next_char.nil?
          value += next_char
          if next_char == "}"
            deel_level -= 1
            if deel_level == 0
              rest.shift
            end
          end

          if next_char == "{"
            deel_level += 1
          end
        end
        rest = rest.join("")
      else
        spliited2 = rest.join.split(",")
        value = spliited2.shift
        rest = spliited2.join(",")
      end
      ret << "#{name}:#{value}"
      s = rest
    end

    ret
  end
end
