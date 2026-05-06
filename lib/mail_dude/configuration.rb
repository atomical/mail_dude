# frozen_string_literal: true

require 'tmpdir'

module MailDude
  class Configuration
    SUPPORTED_STORES = %i[file memory database].freeze

    attr_accessor :allow_production,
                  :capture_attachments,
                  :capture_mailer_metadata_headers,
                  :default_per_page,
                  :enabled_environments,
                  :live_update_authorizer,
                  :live_update_stream_name,
                  :live_updates,
                  :max_message_size,
                  :max_messages,
                  :retention_period,
                  :storage,
                  :storage_path

    def initialize
      @enabled_environments = %w[development qa test]
      @storage = :file
      @storage_path = default_storage_path
      @max_messages = 1_000
      @retention_period = 7.days
      @max_message_size = 25.megabytes
      @allow_production = false
      @capture_attachments = true
      @capture_mailer_metadata_headers = true
      @default_per_page = 50
      @live_updates = false
      @live_update_stream_name = default_live_update_stream_name
      @live_update_authorizer = ->(_connection) { false }
    end

    def validate!
      normalize!
      validate_storage!
      validate_storage_path!
      validate_positive!(:max_messages, max_messages)
      validate_positive!(:retention_period, retention_period)
      validate_positive!(:max_message_size, max_message_size)
      validate_positive!(:default_per_page, default_per_page)
      validate_live_updates!
      self
    end

    private

    def default_storage_path
      if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
        Rails.root.join('tmp/mail_dude')
      else
        Pathname.new(Dir.tmpdir).join('mail_dude')
      end
    end

    def default_live_update_stream_name
      env = if defined?(Rails) && Rails.respond_to?(:env) && Rails.env
              Rails.env
            else
              ENV.fetch('RAILS_ENV', ENV.fetch('RACK_ENV', 'development'))
            end
      "mail_dude:#{env}:messages"
    end

    def normalize!
      @enabled_environments = Array(enabled_environments).map(&:to_s)
      @storage = storage.to_sym if storage.respond_to?(:to_sym)
    end

    def validate_storage!
      return if SUPPORTED_STORES.include?(storage)

      raise InvalidConfigurationError, "storage must be one of: #{SUPPORTED_STORES.join(', ')}"
    end

    def validate_storage_path!
      return unless storage == :file
      return if storage_path.present?

      raise InvalidConfigurationError, 'storage_path must be present when storage is :file'
    end

    def validate_positive!(name, value)
      return if value.nil?
      return if value.respond_to?(:positive?) && value.positive?

      raise InvalidConfigurationError, "#{name} must be positive when configured"
    end

    def validate_live_updates!
      raise InvalidConfigurationError, 'live_update_stream_name must be present' if live_update_stream_name.blank?
      return if live_update_authorizer.respond_to?(:call)

      raise InvalidConfigurationError, 'live_update_authorizer must respond to call'
    end
  end
end
