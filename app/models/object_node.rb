class ObjectNode < ApplicationRecord
  has_many :object_attributes, foreign_key: :parent_id

  def print
    ("{<br>" + print_content + "}").html_safe
  end

  def print_content
    object_attributes.map do |oa|
      "#{oa.print}<br>"
    end.join("").html_safe
  end
end
