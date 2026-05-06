# frozen_string_literal: true

module MailDude
  module MailerMetadataHeaders
    module_function

    def apply(mailer)
      return unless MailDude.configuration.capture_mailer_metadata_headers
      return unless MailDude.enabled?
      return unless mail_dude_delivery?(mailer)

      mailer.message[MessageSerializer::INTERNAL_MAILER_HEADER] = mailer.class.name
      mailer.message[MessageSerializer::INTERNAL_ACTION_HEADER] = mailer.action_name
    end

    def mail_dude_delivery?(mailer)
      mailer.message.delivery_method.is_a?(DeliveryMethod) ||
        mailer.class.delivery_method == :mail_dude ||
        ActionMailer::Base.delivery_method == :mail_dude
    end
  end
end
