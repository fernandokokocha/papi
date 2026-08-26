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

  def self.for_version(auth_methods, base)
    removed = base.auth_methods.reject do |record|
      auth_methods.any? { |auth_method| auth_method.identity_name == record.identity_name }
    end

    live_and_removed = auth_methods.map { |auth_method| [ auth_method, false ] } +
                       removed.map { |record| [ record, true ] }

    new(live_and_removed.map do |record, removal|
      SchemaForm::AuthMethod.new(name: record.name, kind: record.kind, note: record.note, removed: removal)
    end)
  end

  def initialize(auth_methods)
    @auth_methods = auth_methods
  end

  def each(&block)
    @auth_methods.each(&block)
  end

  def adding(name)
    self.class.new([ SchemaForm::AuthMethod.new(name: name, kind: NEW_KIND, note: "", added: true) ] + @auth_methods)
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
