# frozen_string_literal: true

module MailDude
  class Engine < ::Rails::Engine
    ASSET_PRECOMPILE = ['mail_dude/application.css', 'mail_dude/icon.png'].freeze

    isolate_namespace MailDude

    initializer 'mail_dude.action_mailer' do
      ActiveSupport.on_load(:action_mailer) do
        add_delivery_method :mail_dude, MailDude::DeliveryMethod
        after_action { MailDude::MailerMetadataHeaders.apply(self) }
      end
    end

    initializer 'mail_dude.assets' do |app|
      app.config.assets.precompile.concat(ASSET_PRECOMPILE) if app.config.respond_to?(:assets)
    end

    rake_tasks do
      load 'tasks/mail_dude.rake'
    end
  end
end
