class Approval < ApplicationRecord
  belongs_to :candidate
  belongs_to :user

  validates :user_id, uniqueness: { scope: :candidate_id }
  validate :author_cannot_approve

  private

  def author_cannot_approve
    return if candidate.author.nil?
    errors.add(:user, "cannot approve their own candidate") if user == candidate.author
  end
end
