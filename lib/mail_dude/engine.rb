# frozen_string_literal: true

module MailDude
  class Engine < ::Rails::Engine
    isolate_namespace MailDude

    initializer 'mail_dude.action_mailer' do
      ActiveSupport.on_load(:action_mailer) do
        add_delivery_method :mail_dude, MailDude::DeliveryMethod
        after_action { MailDude::MailerMetadataHeaders.apply(self) }
      end
    end

    rake_tasks do
      load 'tasks/mail_dude.rake'
    end
  end
end
