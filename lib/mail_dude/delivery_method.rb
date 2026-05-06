# frozen_string_literal: true

module MailDude
  class DeliveryMethod
    attr_reader :settings

    def initialize(settings = {})
      @settings = settings || {}
    end

    def deliver!(mail)
      raise_disabled! unless MailDude.enabled?

      raw_source = mail.to_s
      validate_size!(raw_source)
      record = MailDude.store.write(mail)
      MessageBroadcast.broadcast(record)
      MailDude.store.prune
      log_capture(record)
      record
    end

    private

    def log_capture(record)
      return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

      Rails.logger.debug { "Captured email #{record.id} subject=#{record.metadata['subject'].to_s.inspect}" }
    end

    def raise_disabled!
      env = MailDude.rails_environment
      message = "MailDude is disabled in #{env}. Configure enabled_environments or set allow_production only " \
                'after reviewing the risks.'
      raise DisabledEnvironmentError, message
    end

    def validate_size!(raw_source)
      limit = MailDude.configuration.max_message_size
      return if limit.nil? || raw_source.bytesize <= limit

      raise MessageTooLargeError,
            "Email is #{raw_source.bytesize} bytes, exceeding MailDude max_message_size of #{limit} bytes."
    end
  end
end
