require "rails_helper"

describe Comment::Reopen do
  it "clears the resolution and reports the change" do
    comment = FactoryBot.create :comment, :resolved

    expect(described_class.new(comment).call).to be true
    expect(comment.reload).not_to be_resolved
    expect(comment.resolved_by_id).to be_nil
  end

  it "reports no change when the thread is already open" do
    comment = FactoryBot.create :comment

    expect(described_class.new(comment).call).to be false
  end
end
