# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MailDude::MessageSerializer do
  let(:captured_at) { Time.utc(2026, 5, 6, 14, 30, 12, 123_456) }

  it 'serializes a plain text message with core metadata' do
    mail = Mail.new do
      from 'Jane Doe <jane@example.com>'
      sender 'sender@example.com'
      to 'User <user@example.com>'
      cc 'cc@example.com'
      bcc 'bcc@example.com'
      reply_to 'reply@example.com'
      date Time.utc(2026, 5, 6, 14, 30)
      message_id 'abc123@example.com'
      in_reply_to 'parent@example.com'
      references 'one@example.com two@example.com'
      body 'Hello'
    end
    mail.subject = 'Welcome'

    metadata = described_class.new(mail, id: 'mid', captured_at: captured_at).metadata

    expect(metadata).to include(
      'id' => 'mid',
      'captured_at' => '2026-05-06T14:30:12.123456Z',
      'subject' => 'Welcome',
      'from' => ['Jane Doe <jane@example.com>'],
      'sender' => ['sender@example.com'],
      'to' => ['User <user@example.com>'],
      'cc' => ['cc@example.com'],
      'bcc' => ['bcc@example.com'],
      'reply_to' => ['reply@example.com'],
      'date' => '2026-05-06T14:30:00Z',
      'message_id' => 'abc123@example.com',
      'in_reply_to' => 'parent@example.com',
      'references' => ['one@example.com', 'two@example.com'],
      'has_text' => true,
      'has_html' => false,
      'has_attachments' => false,
      'attachments_count' => 0
    )
    expect(metadata['size_bytes']).to be_positive
  end

  it 'serializes html, multipart, attachments, and internal mailer metadata' do
    mail = inline_image_mail
    mail[described_class::INTERNAL_MAILER_HEADER] = 'UserMailer'
    mail[described_class::INTERNAL_ACTION_HEADER] = 'welcome'

    metadata = described_class.new(mail, id: 'mid', captured_at: captured_at).metadata

    expect(metadata['mailer']).to eq('UserMailer')
    expect(metadata['mailer_action']).to eq('welcome')
    expect(metadata['has_html']).to be(true)
    expect(metadata['has_attachments']).to be(true)
    expect(metadata['attachments'].first).to include(
      'id' => 'a0',
      'filename' => 'logo.png',
      'content_type' => 'image/png',
      'content_id' => 'logo@example.com',
      'inline' => true
    )
  end

  it 'handles missing and unusual values without crashing' do
    mail = Mail.new
    mail[:to] = 'not an address, still useful'
    allow(mail).to receive(:date).and_raise(StandardError)
    allow(mail).to receive(:subject).and_raise(StandardError)
    allow(mail).to receive(:message_id).and_raise(StandardError)
    allow(mail).to receive(:references).and_raise(StandardError)

    metadata = described_class.new(mail, id: 'mid', captured_at: captured_at, raw_source: 'raw').metadata

    expect(metadata['subject']).to eq('')
    expect(metadata['to']).to eq(['not an address, still useful'])
    expect(metadata['date']).to be_nil
    expect(metadata['message_id']).to be_nil
    expect(metadata['references']).to eq([])
    expect(metadata['size_bytes']).to eq(3)

    empty_mail = Mail.new
    allow(empty_mail).to receive(:date).and_return(nil)
    expect(described_class.new(empty_mail, id: 'empty', captured_at: captured_at).metadata['date']).to be_nil
  end

  it 'handles blank address fallbacks, display-only addresses, header objects, and bad internal headers' do
    mail = plain_mail
    blank_field = double('BlankField')
    allow(blank_field).to receive(:addrs).and_raise(StandardError)
    allow(blank_field).to receive(:to_s).and_return('')
    display_address = double('DisplayAddress', display_name: 'Display Only', address: '')
    display_field = double('DisplayField', addrs: [display_address])
    header_object = double('HeaderObject', value: 'value@example.com')
    bad_header = double('BadHeader')

    allow(bad_header).to receive(:decoded).and_raise(StandardError)
    allow(mail).to receive(:[]).and_call_original
    allow(mail).to receive(:[]).with(:to).and_return(blank_field)
    allow(mail).to receive(:[]).with(:from).and_return(display_field)
    allow(mail).to receive(:[]).with(described_class::INTERNAL_MAILER_HEADER).and_return(bad_header)
    allow(mail).to receive(:message_id).and_return(header_object)

    metadata = described_class.new(mail, id: 'mid', captured_at: captured_at).metadata

    expect(metadata['to']).to eq([])
    expect(metadata['from']).to eq(['Display Only'])
    expect(metadata['message_id']).to eq('value@example.com')
    expect(metadata['mailer']).to be_nil
  end
end
