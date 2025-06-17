module RequestHelpers
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: user.password }
  end

  def sign_out
    delete session_path
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end
