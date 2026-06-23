# frozen_string_literal: true

require 'rails_helper'
require 'rake'
require 'stringio'

RSpec.describe 'mail_dude rake tasks', order: :defined do
  before do
    Rake::Task.clear
    load Rails.root.join('../../lib/tasks/mail_dude.rake')
    Rake::Task.define_task(:environment)
  end

  it 'clears, prunes, and prints stats repeatedly' do
    MailDude.store.write(plain_mail(subject: 'Task'))

    expect(capture_stdout { invoke('mail_dude:stats') }).to match(
      /Storage: memory\nMessages: 1\nPath: .*mail_dude\nTable: mail_dude_stored_emails/
    )

    expect(capture_stdout { invoke('mail_dude:prune') }).to include('Pruned 0 MailDude messages')

    expect(capture_stdout { invoke('mail_dude:clear') }).to include('Cleared 1 MailDude messages')
    expect(capture_stdout { invoke('mail_dude:clear') }).to include('Cleared 0 MailDude messages')
  end

  it 'prints adapter-specific stats for file and database storage' do
    path = Pathname.new(Dir.mktmpdir('mail-dude-task'))
    MailDude.configure do |config|
      config.storage = :file
      config.storage_path = path
    end
    expect(capture_stdout { invoke('mail_dude:stats') }).to match(/Path: #{Regexp.escape(path.to_s)}/)

    create_mail_dude_table!
    MailDude.configure { |config| config.storage = :database }
    expect(capture_stdout { invoke('mail_dude:stats') }).to include('Table: mail_dude_stored_emails')
  ensure
    FileUtils.rm_rf(path) if path
  end

  it 'loads tasks through the engine hook' do
    Rake::Task.clear

    MailDude::Engine.load_tasks
    Rake::Task.define_task(:environment)
    MailDude.store.write(plain_mail(subject: 'Engine task'))

    expect(Rake::Task.task_defined?('mail_dude:stats')).to be(true)
    expect(capture_stdout { invoke('mail_dude:stats') }).to include('Storage: memory')
    expect(capture_stdout { invoke('mail_dude:prune') }).to include('Pruned 0 MailDude messages')
    expect(capture_stdout { invoke('mail_dude:clear') }).to include('Cleared 1 MailDude messages')
  end

  def invoke(name)
    task = Rake::Task[name]
    task.reenable
    task.actions.each { |action| action.call(task, Rake::TaskArguments.new([], [])) }
  end

  def capture_stdout
    original_stdout = $stdout
    captured = StringIO.new
    $stdout = captured
    yield
    captured.string
  ensure
    $stdout = original_stdout
  end
end
