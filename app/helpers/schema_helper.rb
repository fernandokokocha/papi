module SchemaHelper
  CHANGE_TINTS = {
    "added" => "bg-emerald-100 border-emerald-500",
    "removed" => "bg-rose-100 border-rose-500",
    "type_changed" => "bg-amber-100 border-amber-500"
  }.freeze

  def change_tint(change)
    CHANGE_TINTS[change.to_s]
  end
end
