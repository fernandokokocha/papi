# The auth methods submit themselves with every op, so an edit anywhere on the
# page is answered with the names, kinds and notes the form is holding.
class SchemaForm::AuthMethods
  include Enumerable

  NEW_KIND = "bearer".freeze

  def self.from(submitted)
    new((submitted || {}).each_pair.map do |_position, attributes|
      SchemaForm::AuthMethod.new(name: attributes[:name], kind: attributes[:kind], note: attributes[:note],
                                 removed: attributes[:removed].present?, added: attributes[:added].present?)
    end)
  end

  def self.for_version(auth_methods)
    new(auth_methods.map do |auth_method|
      SchemaForm::AuthMethod.new(name: auth_method.name, kind: auth_method.kind, note: auth_method.note)
    end)
  end

  def initialize(auth_methods)
    @auth_methods = auth_methods
  end

  def each(&block)
    @auth_methods.each(&block)
  end

  def adding(name)
    self.class.new(@auth_methods + [ SchemaForm::AuthMethod.new(name: name, kind: NEW_KIND, note: "", added: true) ])
  end

  def dropping(position)
    self.class.new(@auth_methods.reject.with_index { |_auth_method, index| index == position })
  end

  def removing(position)
    at(position) { |auth_method| auth_method.with_removed(true) }
  end

  def restoring(position)
    at(position) { |auth_method| auth_method.with_removed(false) }
  end

  def removed_twin_position(name)
    find_index { |auth_method| auth_method.removed && auth_method.name == name }
  end

  def new_name_error(name)
    return "An auth method needs a name" if name.blank?
    return "This auth method already exists" if reject(&:removed).any? { |auth_method| auth_method.name == name }

    nil
  end

  private

  def at(position)
    self.class.new(@auth_methods.map.with_index { |auth_method, index| index == position ? yield(auth_method) : auth_method })
  end
end
