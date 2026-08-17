class DiffAuth::FromAuth
  NONE = "none".freeze
  NO_CHANGE = "no_change".freeze

  def initialize(previous_auth_method, auth_method)
    @previous = previous_auth_method
    @current = auth_method
  end

  def before_line
    Diff::Line.new(label(@previous), @previous.nil? ? NO_CHANGE : change, 1)
  end

  def after_line
    Diff::Line.new(label(@current), @current.nil? ? NO_CHANGE : change, 1)
  end

  def any_changes?
    change != NO_CHANGE
  end

  private

  def change
    @change ||= compute_change
  end

  def compute_change
    return NO_CHANGE if @previous.nil? && @current.nil?
    return "added" if @previous.nil?
    return "removed" if @current.nil?

    @current.same_contract_as?(@previous) ? NO_CHANGE : "type_changed"
  end

  def label(auth_method)
    return NONE if auth_method.nil?

    "#{auth_method.name} #{auth_method.kind}"
  end
end
