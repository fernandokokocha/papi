# Endpoints, entities and auth methods are all matched across two versions the
# same way: by the name a client would know them by. Each record is annotated in
# place, and a removal is carried over from the before side so the page can show
# what is gone.
class Comparison::CategorizeByName
  def initialize(before, after)
    @before = before
    @after = after
  end

  def call
    (annotated_after + annotated_removals).sort_by(&:sort_name)
  end

  private

  def annotated_after
    @after.each do |record|
      record.previous = before_by_name[record.identity_name]
      record.annotation = annotation_for(record)
    end
  end

  def annotation_for(record)
    return "added" if record.previous.nil?

    record.differs_from?(record.previous) ? "changed" : "unchanged"
  end

  def annotated_removals
    @before.reject { |record| after_names.include?(record.identity_name) }
           .each { |record| record.annotation = "removed" }
  end

  def before_by_name
    @before_by_name ||= @before.index_by(&:identity_name)
  end

  def after_names
    @after_names ||= @after.map(&:identity_name).to_set
  end
end
