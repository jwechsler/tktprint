require_relative 'boot'

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "active_job/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Tktprint2
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    config.api_only = true

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    
    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Use delayed job for background processing
    config.active_job.queue_adapter = :delayed_job
    
    # Load configuration files if they exist
    printer_config_file = Rails.root.join('config/printer.yml')
    auth_config_file = Rails.root.join('config/authorization.yml')

    if File.exist?(printer_config_file)
      printer_config = YAML.load_file(printer_config_file)
      # Accept both env-keyed files (development:/test:/production:) and the flat
      # files that start-printer.sh copies into place (ticket_printer_1: at top level).
      env_config = printer_config[Rails.env] || printer_config['production'] || printer_config
      $PRINTER = [env_config['ticket_printer_1']] if env_config && env_config['ticket_printer_1']
    end

    if File.exist?(auth_config_file)
      auth_config = YAML.load_file(auth_config_file) 
      $XML_AUTHORIZATION = auth_config[Rails.env] || auth_config['production']
    end
  end
end
