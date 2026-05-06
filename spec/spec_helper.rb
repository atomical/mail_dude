# frozen_string_literal: true

require 'simplecov'

SimpleCov.enable_coverage :branch
SimpleCov.command_name 'RSpec'
SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/test/'
  add_filter '/vendor/'
  add_filter '/spec/dummy/'
  add_group 'Controllers', 'app/controllers'
  add_group 'Models', 'app/models'
  add_group 'Libraries', 'lib'
end

SimpleCov.minimum_coverage line: 100, branch: 100
SimpleCov.minimum_coverage_by_file line: 100, branch: 100

require 'bundler/setup'

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  config.order = :random
  Kernel.srand config.seed
end
