# frozen_string_literal: true

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative 'dummy/config/environment'
require 'rspec/rails'
require 'active_support/testing/time_helpers'

ActiveRecord::Migration.verbose = false

module MailDudeSpecHelpers
  def create_mail_dude_table!
    drop_mail_dude_table!
    ActiveRecord::Schema.define do
      create_table :mail_dude_stored_emails do |t|
        t.string :uid, null: false
        t.datetime :captured_at, null: false
        t.string :subject
        t.text :from_addresses_json
        t.text :sender_addresses_json
        t.text :to_addresses_json
        t.text :cc_addresses_json
        t.text :bcc_addresses_json
        t.text :reply_to_addresses_json
        t.string :message_id
        t.string :content_type
        t.string :mailer
        t.string :mailer_action
        t.boolean :has_html, null: false, default: false
        t.boolean :has_text, null: false, default: false
        t.boolean :has_attachments, null: false, default: false
        t.integer :attachments_count, null: false, default: 0
        t.integer :size_bytes, null: false, default: 0
        t.text :metadata_json, null: false
        t.binary :raw_message, null: false
        t.timestamps
      end
      add_index :mail_dude_stored_emails, :uid, unique: true
      add_index :mail_dude_stored_emails, :captured_at
      add_index :mail_dude_stored_emails, :message_id
      add_index :mail_dude_stored_emails, :mailer
      add_index :mail_dude_stored_emails, :mailer_action
    end
  end

  def drop_mail_dude_table!
    return unless ActiveRecord::Base.connection.data_source_exists?(:mail_dude_stored_emails)

    ActiveRecord::Schema.define { drop_table :mail_dude_stored_emails }
  end

  def plain_mail(subject: 'Plain', to: 'to@example.com', body: 'Hello from MailDude')
    Mail.new do
      from 'from@example.com'
      to to
      subject subject
      date Time.utc(2026, 5, 6, 14, 30)
      message_id 'abc123@example.com'
      text_part { body body }
    end
  end

  def html_mail(subject: 'HTML', html: '<h1>Hello</h1>')
    Mail.new do
      from 'from@example.com'
      to 'to@example.com'
      subject subject
      content_type 'text/html; charset=UTF-8'
      body html
    end
  end

  def alternative_mail
    Mail.new do
      from 'from@example.com'
      to 'to@example.com'
      subject 'Alternative'
      text_part { body 'Plain body' }
      html_part do
        content_type 'text/html; charset=UTF-8'
        body '<p>HTML body</p>'
      end
    end
  end

  def attachment_mail(filename: 'report.pdf', content_type: 'application/pdf')
    mail = plain_mail(subject: 'Attachment')
    mail.add_file filename: filename, content: 'PDFDATA'
    mail.attachments[filename].content_type = content_type if content_type
    mail
  end

  def inline_image_mail
    mail = Mail.new do
      from 'from@example.com'
      to 'to@example.com'
      subject 'Inline'
      html_part do
        content_type 'text/html; charset=UTF-8'
        body '<img src="cid:logo@example.com"><a href="https://example.com">Go</a>'
      end
    end
    mail.attachments.inline['logo.png'] = 'PNGDATA'
    mail.attachments['logo.png'].content_id = '<logo@example.com>'
    mail.attachments['logo.png'].content_type = 'image/png'
    mail
  end
end

RSpec.configure do |config|
  config.include MailDudeSpecHelpers
  config.include ActiveSupport::Testing::TimeHelpers
  config.fixture_paths = [File.expand_path('fixtures', __dir__)]
  config.use_transactional_fixtures = false
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before do
    MailDude.reset_configuration!
    MailDude.configure do |mail_dude|
      mail_dude.storage = :memory
      mail_dude.enabled_environments = %w[test development qa]
      mail_dude.default_per_page = 2
    end
    ActionMailer::Base.deliveries.clear
    ActionMailer::Base.delivery_method = :mail_dude
  end

  config.after do
    MailDude.store.clear if MailDude.instance_variable_defined?(:@store) && MailDude.instance_variable_get(:@store)
    drop_mail_dude_table!
    MailDude.reset_configuration!
  end
end
