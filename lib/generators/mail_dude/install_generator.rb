# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'

module MailDude
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)
      class_option :database, type: :boolean, default: false, desc: 'Install the database storage migration'

      def copy_initializer
        @storage = options[:database] ? ':database' : ':file'
        template 'initializer.tt', 'config/initializers/mail_dude.rb'
      end

      def copy_migration
        return unless options[:database]

        migration_template 'create_mail_dude_stored_emails.tt', 'db/migrate/create_mail_dude_stored_emails.rb'
      end

      def print_next_steps
        puts <<~TEXT

          Mount MailDude behind host app authentication and authorization:

            authenticate :user, lambda { |u| Ability.new(u).can?(:manage, MailDude::Dashboard) } do
              mount MailDude::Engine, at: "/mail_dude"
            end

          Configure Action Mailer in development or QA:

            config.action_mailer.delivery_method = :mail_dude
            config.action_mailer.perform_deliveries = true

          MailDude does not authenticate users itself. Do not expose /mail_dude publicly.
        TEXT
        puts 'Run bin/rails db:migrate before using database storage.' if options[:database]
      end

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end
    end
  end
end
