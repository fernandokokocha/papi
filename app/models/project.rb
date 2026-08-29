class Project < ApplicationRecord
  has_many :versions, dependent: :destroy
  has_many :candidates, dependent: :destroy
  belongs_to :group

  validates :name, uniqueness: { scope: :group_id }

  def latest_version
    versions.order(order: :desc).first || Version.null_version(self)
  end

  def latest_candidate
    candidates.order(order: :desc).first || null_candidate
  end

  def history
    @history ||= candidates.includes(:author, :decided_by, :version, approvals: :user, comments: :author).order(order: :desc)
  end

  Event = Struct.new(:at, :actor, :verb, :candidate, :version, :count, keyword_init: true)

  def events
    history.flat_map { |candidate| events_for(candidate) }.sort_by(&:at).reverse
  end

  def null_candidate
    Candidate.new(project: self, name: "", order: 0, created_at: NullTime.new)
  end

  def can_create_candidate?
    candidates.open.empty?
  end

  def next_version_order
    max_version = versions.maximum(:order) || 0
    max_version + 1
  end

  def next_version_name
    "v#{next_version_order}"
  end

  def to_param
    name
  end

  private

  def events_for(candidate)
    list = [ Event.new(at: candidate.created_at, actor: candidate.author, verb: :opened, candidate: candidate) ]

    candidate.approvals.each do |approval|
      list << Event.new(at: approval.created_at, actor: approval.user, verb: :approved, candidate: candidate)
    end

    list.concat(comment_events(candidate))

    if candidate.decided_at
      list << Event.new(at: candidate.decided_at, actor: candidate.decided_by, verb: candidate.aasm_state.to_sym,
                        candidate: candidate, version: candidate.promoted_version)
    end

    list
  end

  def comment_events(candidate)
    candidate.comments.group_by { |comment| [ comment.author, comment.created_at.to_date ] }
      .map do |(author, _date), comments|
        Event.new(at: comments.map(&:created_at).max, actor: author, verb: :commented,
                  candidate: candidate, count: comments.size)
      end
  end
end
