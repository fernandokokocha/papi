class ApplicationMailer < ActionMailer::Base
  default from: "Papi <#{Rails.application.credentials.dig(:smtp, :mailbox)}>"
  layout "mailer"
end
