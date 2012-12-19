gem 'sass-rails',     '~> 3.2.3'
gem 'compass-rails',  '~> 1.0.3'

group :assets do
  gem 'compass-960-plugin', '>= 0.10.4', :require => 'ninesixty'
  gem 'uglifier',       '>= 1.0.3'
  gem 'therubyracer',   :platforms => :ruby
end
