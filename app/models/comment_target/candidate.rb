class CommentTarget::Candidate
  def self.build(_identity) = new

  def scope = "candidate"
  def kind = :conversation
  def parts = %w[whole]
  def required = []
end
