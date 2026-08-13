# Answers "which node does each rendered line stand for?" by reading the lines
# themselves rather than instrumenting the thirty-six Diff classes that emit
# them. The emitted output is the ground truth, so this cannot drift from it.
#
# Paths match the ones the React editor threads through every node: an object
# attribute by name, an array element as nil, a one-of branch by index.
class SchemaPathIndex
  OPENERS = { "{" => :object, "[" => :array, "(" => :one_of }.freeze
  CLOSERS = [ "}", "]", ")" ].freeze
  private_constant :OPENERS, :CLOSERS

  def initialize(lines)
    @lines = lines.lines
  end

  def to_a
    @stack = []
    @pending = nil

    @lines.map { |line| path_for(line.whole_line) }
  end

  # An object attribute holding a container spans two lines — its label and the
  # opening brace — and both name the same node, so a note belongs on the first.
  def first_row_per_path
    rows = {}
    to_a.each_with_index { |path, row| rows[path] ||= row unless path.nil? }
    rows
  end

  private

  def path_for(text)
    return nil if text.empty?
    return close if CLOSERS.include?(text)
    return open(text) if OPENERS.key?(text)
    return label(text) if text.end_with?(":")
    return child_path(attribute_name(text)) if text.include?(":")

    child_path(nil)
  end

  def close
    @stack.pop.fetch(:path)
  end

  def open(text)
    path = @pending || child_path(nil)
    @pending = nil
    @stack.push(kind: OPENERS.fetch(text), path: path, branch: 0)
    path
  end

  def label(text)
    @pending = child_path(attribute_name(text))
  end

  def child_path(name)
    frame = @stack.last
    return [] if frame.nil?

    case frame.fetch(:kind)
    when :object then frame.fetch(:path) + [ name ]
    when :array  then frame.fetch(:path) + [ nil ]
    when :one_of then frame.fetch(:path) + [ next_branch(frame) ]
    end
  end

  def next_branch(frame)
    index = frame.fetch(:branch)
    frame[:branch] = index + 1
    index
  end

  def attribute_name(text)
    text.split(":", 2).first.strip.delete_suffix("?")
  end
end
