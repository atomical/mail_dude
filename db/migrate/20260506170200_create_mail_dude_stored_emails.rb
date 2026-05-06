# frozen_string_literal: true

class CreateMailDudeStoredEmails < ActiveRecord::Migration[7.1]
  def change
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
