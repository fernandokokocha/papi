FakeEntity = Struct.new(:name, :root) do
  def parsed_root
    JSONSchemaParser.new.parse_value(root)
  end

  def differs_from?(previous)
    Diff::FromValues.new(previous.parsed_root, parsed_root).any_changes?
  end
end
