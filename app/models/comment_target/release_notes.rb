class CommentTarget::ReleaseNotes
  def self.build(_identity) = new

  def scope = "release_notes"
  def kind = :release_notes
  def parts = %w[whole]
  def required = []
end
