class SchemaForm::Response
  attr_reader :code, :note

  def initialize(code:, note:)
    @code = code
    @note = note
  end
end
