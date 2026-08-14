class CommentTarget::ReleaseNotes
  def self.build(_identity) = new

  def scope = "release_notes"
  def parts = %w[whole]
  def required = []
  def label_segments = []
end
