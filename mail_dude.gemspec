# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'mail_dude'
  spec.version = '0.1.1'
  spec.authors = ['MailDude contributors']
  spec.email = ['mail_dude@example.com']
  spec.summary = 'A Rails Action Mailer capture engine for development and QA.'
  spec.description = 'MailDude captures Action Mailer deliveries and displays them in a mountable Rails engine.'
  spec.homepage = 'https://example.com/mail_dude'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(__dir__) do
    Dir['{app,config,db,lib}/**/*', 'CHANGELOG.md', 'LICENSE.txt', 'README.md']
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'rails', '>= 7.0.3.1', '< 8.0'

  spec.add_development_dependency 'capybara', '~> 3.40'
  spec.add_development_dependency 'rspec-rails', '~> 7.1'
  spec.add_development_dependency 'rubocop', '~> 1.75'
  spec.add_development_dependency 'rubocop-rails', '~> 2.30'
  spec.add_development_dependency 'rubocop-rake', '~> 0.7'
  spec.add_development_dependency 'rubocop-rspec', '~> 3.5'
  spec.add_development_dependency 'simplecov', '~> 0.22'
  spec.add_development_dependency 'sqlite3', '>= 1.4', '< 3.0'
end
