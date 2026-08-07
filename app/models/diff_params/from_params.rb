class DiffParams::FromParams
  Row = Data.define(:name, :line) do
    def removed? = line.change == "removed"
  end

  def initialize(previous_params, params)
    @previous_by_name = previous_params.index_by(&:name)
    @by_name = params.index_by(&:name)
    @names = (previous_params.map(&:name) + params.map(&:name)).uniq
  end

  def before_rows
    rows(@previous_by_name)
  end

  def after_rows
    rows(@by_name)
  end

  def any_changes?
    @names.any? { |name| change_for(name) != "no_change" }
  end

  private

  def rows(by_name)
    @names.filter_map do |name|
      param = by_name[name]
      Row.new(name: name, line: line(name, param, change_for(name))) if param
    end
  end

  def change_for(name)
    previous = @previous_by_name[name]
    current = @by_name[name]

    return "added" if previous.nil?
    return "removed" if current.nil?
    previous.kind == current.kind ? "no_change" : "type_changed"
  end

  def line(name, param, change)
    Diff::Line.new("#{padded(name)} #{param.kind}", change, 1)
  end

  def padded(name)
    ":#{name}".ljust(name_column_width)
  end

  def name_column_width
    @name_column_width ||= @names.map { |name| name.length + 1 }.max
  end
end
