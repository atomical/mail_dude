# frozen_string_literal: true

module MailDude
  class StoredEmail < ApplicationRecord
    self.table_name = 'mail_dude_stored_emails'
  end
end
