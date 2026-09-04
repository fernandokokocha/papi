class PasswordsMailerPreview < ActionMailer::Preview
  def reset
    PasswordsMailer.reset(User.first)
  end
end
