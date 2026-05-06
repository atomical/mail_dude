# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext'
require 'json'
require 'mail'
require 'pathname'
require 'rails'

require_relative 'mail_dude/version'
require_relative 'mail_dude/errors'
require_relative 'mail_dude/configuration'
require_relative 'mail_dude/dashboard'
require_relative 'mail_dude/message_record'
require_relative 'mail_dude/pagination'
require_relative 'mail_dude/message_serializer'
require_relative 'mail_dude/message_presenter'
require_relative 'mail_dude/attachment_locator'
require_relative 'mail_dude/html_body_renderer'
require_relative 'mail_dude/message_broadcast'
require_relative 'mail_dude/stores/base'
require_relative 'mail_dude/stores/memory_store'
require_relative 'mail_dude/stores/file_store'
require_relative 'mail_dude/stores/database_store'
require_relative 'mail_dude/delivery_method'
require_relative 'mail_dude/mailer_metadata_headers'
require_relative 'mail_dude/engine'

module MailDude
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
      configuration.validate!
      reset_store!
    end

    def reset_configuration!
      @configuration = Configuration.new
      reset_store!
    end

    def enabled?(environment = rails_environment)
      config = configuration.validate!
      env = environment.to_s
      return true if env == 'production' && config.allow_production
      return false if env == 'production'

      config.enabled_environments.include?(env)
    end

    def store
      @store ||= build_store
    end

    def reset_store!
      @store = nil
    end

    def rails_environment
      return Rails.env if defined?(Rails) && Rails.respond_to?(:env) && Rails.env

      ENV.fetch('RAILS_ENV', ENV.fetch('RACK_ENV', 'development'))
    end

    private

    def build_store
      factories = {
        file: -> { Stores::FileStore.new(configuration.storage_path) },
        memory: -> { Stores::MemoryStore.new },
        database: -> { Stores::DatabaseStore.new }
      }
      factories.fetch(configuration.validate!.storage).call
    end
  end
end
