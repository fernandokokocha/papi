class CommentTarget::Candidate
  def self.build(_identity) = new

  def scope = "candidate"
  def parts = %w[whole]
  def required = []
  def label_segments = []
end
