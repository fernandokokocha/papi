class DiffAuth::FromAuth
  NONE = "none".freeze

  def initialize(previous_auth_method, auth_method)
    @previous = previous_auth_method
    @current = auth_method
  end

  def before_line
    Diff::Line.new(label(@previous), change, 1)
  end

  def after_line
    Diff::Line.new(label(@current), change, 1)
  end

  def any_changes?
    change != "no_change"
  end

  private

  def change
    @change ||= compute_change
  end

  def compute_change
    return "no_change" if @previous.nil? && @current.nil?
    return "added" if @previous.nil?
    return "removed" if @current.nil?

    @current.same_contract_as?(@previous) ? "no_change" : "type_changed"
  end

  def label(auth_method)
    return NONE if auth_method.nil?

    "#{auth_method.name} #{auth_method.kind}"
  end
end
