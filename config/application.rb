require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Papi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.eager_load_paths << Rails.root.join("extras")

    config.time_zone = "Europe/Warsaw"

    config.action_mailer.smtp_settings = {
      address: "ssl0.ovh.net",
      port: 587,
      user_name: Rails.application.credentials.dig(:smtp, :mailbox),
      password: Rails.application.credentials.dig(:smtp, :password),
      authentication: :plain
    }

    config.generators do |g|
      g.factory_bot dir: "spec/factories"
    end
  end
end
