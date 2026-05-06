# frozen_string_literal: true

require_relative 'boot'
require 'rails/all'
require_relative '../../../lib/mail_dude'

Bundler.require(*Rails.groups)

module Dummy
  class Application < Rails::Application
    config.load_defaults 7.2
    config.root = Pathname.new(File.expand_path('..', __dir__))
    config.eager_load = false
    config.secret_key_base = 'test-secret-key-base'
    config.hosts.clear
    config.active_record.maintain_test_schema = false
    config.action_mailer.delivery_method = :mail_dude
    config.action_mailer.perform_deliveries = true
    config.action_controller.allow_forgery_protection = false
  end
end
