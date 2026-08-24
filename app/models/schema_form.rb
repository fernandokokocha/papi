module SchemaForm
  # The editor's controls belong to a form of their own: nested forms are
  # illegal, and the candidate form must keep submitting the plain way.
  OPS_FORM_ID = "schema_ops".freeze

  # The submit bar is pinned above the form it submits, so its button reaches
  # the form by id rather than by nesting.
  FORM_ID = "candidate_form".freeze
end
