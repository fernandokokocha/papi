module SchemaHelper
  CHANGE_TINTS = {
    "added" => "bg-emerald-100 border-emerald-500",
    "removed" => "bg-rose-100 border-rose-500",
    "type_changed" => "bg-amber-100 border-amber-500"
  }.freeze

  TYPE_TINTS = {
    "string" => "bg-green-100 text-green-800 ring-green-200",
    "number" => "bg-blue-100 text-blue-800 ring-blue-200",
    "boolean" => "bg-orange-100 text-orange-800 ring-orange-200",
    "null" => "bg-red-100 text-red-800 ring-red-200",
    "custom" => "bg-violet-100 text-violet-800 ring-violet-300",
    "nothing" => "bg-slate-100 text-slate-500 ring-slate-300"
  }.freeze

  def change_tint(change)
    CHANGE_TINTS[change.to_s]
  end

  # An entity is named by its own name, so anything the map does not know is
  # a reference to one.
  def type_tint(class_name)
    TYPE_TINTS.fetch(class_name.to_s, TYPE_TINTS["custom"])
  end
end
