# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MailDude::DeliveryMethod do
  it 'registers with Action Mailer and captures without external delivery' do
    expect(ActionMailer::Base.delivery_methods[:mail_dude]).to eq(described_class)

    TestMailer.plain.deliver_now
    record = MailDude.store.list.records.first

    expect(record).to be_a(MailDude::MessageRecord)
    expect(MailDude.store.list.total_count).to eq(1)
    expect(ActionMailer::Base.deliveries).to eq([])
  end

  it 'initializes with nil settings, logs, and prunes after write' do
    MailDude.configure do |config|
      config.storage = :memory
      config.max_messages = 1
    end
    allow(Rails.logger).to receive(:debug)

    method = described_class.new(nil)
    first = method.deliver!(plain_mail(subject: 'First'))
    second = method.deliver!(plain_mail(subject: 'Second'))

    expect(method.settings).to eq({})
    expect(MailDude.store.find(second.id).metadata['subject']).to eq('Second')
    expect { MailDude.store.find(first.id) }.to raise_error(MailDude::MessageNotFoundError)
    expect(Rails.logger).to have_received(:debug).twice
  end

  it 'broadcasts the captured record after writing' do
    allow(MailDude::MessageBroadcast).to receive(:broadcast)

    record = described_class.new.deliver!(plain_mail)

    expect(MailDude::MessageBroadcast).to have_received(:broadcast).with(record)
  end

  it 'captures without logging when no Rails logger is configured' do
    allow(Rails).to receive(:logger).and_return(nil)

    expect(described_class.new.deliver!(plain_mail)).to be_a(MailDude::MessageRecord)
  end

  it 'raises when disabled and when messages exceed max size' do
    MailDude.configure do |config|
      config.storage = :memory
      config.enabled_environments = []
    end

    expect { described_class.new.deliver!(plain_mail) }.to raise_error(MailDude::DisabledEnvironmentError, /disabled/)

    MailDude.configure do |config|
      config.storage = :memory
      config.enabled_environments = %w[test]
      config.max_message_size = 1
    end
    expect { described_class.new.deliver!(plain_mail) }.to raise_error(MailDude::MessageTooLargeError, /exceeding/)
  end

  it 'allows production only through the explicit escape hatch' do
    allow(MailDude).to receive(:rails_environment).and_return('production')
    MailDude.configure do |config|
      config.storage = :memory
      config.allow_production = true
    end

    expect(described_class.new.deliver!(plain_mail)).to be_a(MailDude::MessageRecord)
  end

  it 'adds mailer metadata headers only for MailDude delivery' do
    mail = TestMailer.plain
    mail.deliver_now
    stored = MailDude.store.list.records.first
    expect(stored.metadata['mailer']).to eq('TestMailer')
    expect(stored.metadata['mailer_action']).to eq('plain')

    MailDude.store.clear
    MailDude.configure do |config|
      config.storage = :memory
      config.capture_mailer_metadata_headers = false
    end
    TestMailer.plain.deliver_now
    expect(MailDude.store.list.records.first.metadata['mailer']).to be_nil

    ActionMailer::Base.delivery_method = :test
    mail = TestMailer.plain
    mail.message.deliver
    expect(mail.message[MailDude::MessageSerializer::INTERNAL_MAILER_HEADER]).to be_nil
  ensure
    ActionMailer::Base.delivery_method = :mail_dude
  end

  it 'returns early from metadata header capture when disabled or not using MailDude' do
    fake_class = double('FakeMailerClass', name: 'FakeMailer', delivery_method: :mail_dude)
    mail = plain_mail
    fake_mailer = instance_double(ActionMailer::Base, message: mail, action_name: 'welcome')
    allow(fake_mailer).to receive(:class).and_return(fake_class)

    MailDude.configure do |config|
      config.storage = :memory
      config.enabled_environments = []
    end
    MailDude::MailerMetadataHeaders.apply(fake_mailer)
    expect(mail[MailDude::MessageSerializer::INTERNAL_MAILER_HEADER]).to be_nil

    MailDude.configure do |config|
      config.storage = :memory
      config.enabled_environments = %w[test]
    end
    ActionMailer::Base.delivery_method = :test
    allow(fake_class).to receive(:delivery_method).and_return(:test)
    allow(mail).to receive(:delivery_method).and_return(Object.new)
    MailDude::MailerMetadataHeaders.apply(fake_mailer)
    expect(mail[MailDude::MessageSerializer::INTERNAL_MAILER_HEADER]).to be_nil
  ensure
    ActionMailer::Base.delivery_method = :mail_dude
  end
end
