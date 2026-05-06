# frozen_string_literal: true

namespace :mail_dude do
  desc 'Clear all captured MailDude messages'
  task clear: :environment do
    count = MailDude.store.clear
    puts "Cleared #{count} MailDude messages"
  end

  desc 'Prune captured MailDude messages using configured retention'
  task prune: :environment do
    count = MailDude.store.prune
    puts "Pruned #{count} MailDude messages"
  end

  desc 'Print MailDude storage statistics'
  task stats: :environment do
    store = MailDude.store
    page = store.list(per_page: 1)
    puts "Storage: #{MailDude.configuration.storage}"
    puts "Messages: #{page.total_count}"
    puts "Path: #{MailDude.configuration.storage_path}"
    puts "Table: #{MailDude::StoredEmail.table_name}"
  end
end
