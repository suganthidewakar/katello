require 'rails'

if ::Rails.env != "test"
  # This configuration file works with both the Compass command line tool and within Rails.
  require 'ninesixty'
  # Require any additional compass plugins here.

  project_type = :rails
  # Set this to the root of your project when deployed:
  http_path = ENV['RAILS_RELATIVE_URL_ROOT'] || '/'
  environment = Compass::AppIntegration::Rails.env
end
