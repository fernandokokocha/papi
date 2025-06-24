module ApplicationHelper
  def render_type(diff_line, tab = 2)
    indent_part = (" " * (diff_line.indent * tab))
    unless diff_line.pre_type
      return indent_part + diff_line.whole_line
    end

    type_part = if diff_line.class_name == "custom"
                  link_to diff_line.type, "#entity-#{diff_line.type}"
    else
                  diff_line.type
    end

    (indent_part + diff_line.pre_type + "<span class=\"#{diff_line.class_name}\">#{type_part}</span>").html_safe
  end
end
