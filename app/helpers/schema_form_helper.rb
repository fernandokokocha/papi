# The form reads as the diff, so its sidebar has to name each card the same way
# its header does: against the version the candidate branched from.
module SchemaFormHelper
  def endpoint_form_annotation(endpoint, blocks, auth_methods, base)
    return "removed" if endpoint.removed

    base_endpoint = base.endpoints.find { |record| record.identity_name == endpoint.identity_name }
    return "added" if base_endpoint.nil?

    chosen = auth_methods.reject(&:removed).find { |auth_method| auth_method.name == endpoint.auth }
    "changed" if SchemaForm::EndpointDiff.new(base_endpoint, endpoint, blocks, chosen).any_changes?
  end

  def entity_form_annotation(block, blocks, base)
    return "removed" if block.removed

    base_entity = base.entities.find { |entity| entity.identity_name == block.name }
    return "added" if base_entity.nil?

    "changed" if Diff::FromValues.new(base_entity.parsed_root, blocks.parse(block)).any_changes?
  end

  def auth_method_form_annotation(auth_method, base)
    return "removed" if auth_method.removed

    base_auth_method = base.auth_methods.find { |record| record.identity_name == auth_method.name }
    return "added" if base_auth_method.nil?

    return "changed" if base_auth_method.kind != auth_method.kind

    "changed" if DiffText::FromNotes.new(base_auth_method.note, auth_method.note).any_changes?
  end
end
