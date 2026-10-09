group :development do
  # web-console is not required for plugin tests
  # gem 'web-console', '~> 4.1.0'
end

group :development, :test do
  gem 'rails-controller-testing' unless dependencies.any? { |d| d.name == 'rails-controller-testing' }
  gem 'byebug'
end

group :test do
  gem 'ruby-prof'
end
