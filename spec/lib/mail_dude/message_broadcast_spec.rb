# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MailDude::MessageBroadcast do
  it 'does nothing when live updates are disabled' do
    record = MailDude.store.write(plain_mail)

    expect(described_class.broadcast(record)).to be(false)
  end

  it 'does nothing when Action Cable is unavailable' do
    record = MailDude.store.write(plain_mail)
    MailDude.configure do |config|
      config.storage = :memory
      config.live_updates = true
    end
    hide_const('ActionCable')

    expect(described_class.broadcast(record)).to be(false)
  end

  it 'broadcasts only safe list metadata when enabled' do
    captured_payload = nil
    server = instance_double(ActionCable::Server::Base)
    allow(ActionCable).to receive(:server).and_return(server)
    allow(server).to receive(:broadcast) do |_stream, payload|
      captured_payload = payload
      true
    end
    MailDude.configure do |config|
      config.storage = :memory
      config.live_updates = true
      config.live_update_stream_name = 'mail_dude:test:custom'
    end
    record = MailDude.store.write(attachment_mail)

    expect(described_class.broadcast(record)).to be(true)
    expect(server).to have_received(:broadcast).with(
      'mail_dude:test:custom',
      hash_including(
        event: 'message_created',
        id: record.id,
        subject: 'Attachment',
        sender: 'from@example.com',
        recipients: 'to@example.com',
        attachments_count: 1
      )
    )
    expect(captured_payload.to_s).not_to include('PDFDATA', 'Subject: Attachment')
  end
end
