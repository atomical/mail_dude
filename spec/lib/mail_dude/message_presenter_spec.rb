# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MailDude::MessagePresenter do
  it 'formats metadata and display fallbacks' do
    record = MailDude::MessageRecord.new(
      id: 'id',
      metadata: {
        'subject' => '',
        'captured_at' => 'bad',
        'from' => [],
        'sender' => [],
        'to' => [],
        'cc' => [],
        'bcc' => [],
        'reply_to' => [],
        'mailer' => nil,
        'mailer_action' => 'welcome',
        'size_bytes' => 512,
        'attachments' => []
      }
    )
    presenter = described_class.new(record)

    expect(presenter.subject_label).to eq('(no subject)')
    expect(presenter.captured_at).to be_nil
    expect(presenter.captured_at_label).to eq('(unknown time)')
    expect(presenter.sender_summary).to eq('(unknown sender)')
    expect(presenter.recipient_summary).to eq('(no recipients)')
    expect(presenter.mailer_label).to eq('#welcome')
    expect(presenter.size_label).to eq('512 B')
    expect(presenter.attachment_count_label).to eq('0 attachments')
  end

  it 'formats loaded messages, bodies, headers, sizes, mailer labels, and previews' do
    record = MailDude.store.write(alternative_mail)
    presenter = described_class.new(record)

    expect(presenter.id).to eq(record.id)
    expect(presenter.subject_label).to eq('Alternative')
    expect(presenter.captured_at_label).to include('UTC')
    expect(presenter.mailer_label).to eq('(unknown mailer)')
    expect(presenter.html_body).to include('HTML body')
    expect(presenter.text_body).to include('Plain body')
    expect(presenter.raw_headers).to include('Subject: Alternative')
    expect(presenter.raw_source).to include('Alternative')
    expect(presenter.list_preview).to include('Plain body')
    expect(presenter.size_label).to match(/(KB|B)\z/)
  end

  it 'formats larger sizes and full mailer labels' do
    record = MailDude::MessageRecord.new(
      id: 'id',
      metadata: {
        'captured_at' => '2026-05-06T14:30:00Z',
        'from' => ['from@example.com'],
        'to' => ['to@example.com'],
        'mailer' => 'UserMailer',
        'mailer_action' => 'welcome',
        'size_bytes' => 1.5.megabytes.to_i,
        'attachments' => [{ 'id' => 'a0' }]
      },
      raw_source: 'bad mail'
    )

    presenter = described_class.new(record)

    expect(presenter.captured_at).to eq(Time.utc(2026, 5, 6, 14, 30))
    expect(presenter.mailer_label).to eq('UserMailer#welcome')
    expect(presenter.size_label).to eq('1.5 MB')
    expect(presenter).to have_attributes(from: ['from@example.com'], to: ['to@example.com'])
    expect(presenter).to be_has_attachments
    expect(presenter.attachment_count_label).to eq('1 attachment')
    expect(presenter.mail).to be_a(Mail::Message)
  end

  it 'reports attachment presence from metadata when attachment details are omitted' do
    record = MailDude::MessageRecord.new(
      id: 'id',
      metadata: {
        'has_attachments' => true,
        'attachments_count' => 2,
        'attachments' => []
      }
    )
    presenter = described_class.new(record)

    expect(presenter).to be_has_attachments
    expect(presenter.attachment_count).to eq(2)
    expect(presenter.attachment_count_label).to eq('2 attachments')
  end

  it 'covers mailer-only labels, kilobyte sizes, blank raw source, and html previews' do
    record = MailDude::MessageRecord.new(
      id: 'id',
      metadata: {
        'mailer' => 'UserMailer',
        'mailer_action' => nil,
        'size_bytes' => 1_500,
        'attachments' => []
      }
    )
    presenter = described_class.new(record)

    expect(presenter.mailer_label).to eq('UserMailer')
    expect(presenter.size_label).to eq('1.5 KB')
    expect(presenter.mail).to be_nil
    expect(presenter.raw_headers).to eq('')
    expect(presenter.html_body).to be_nil

    html_record = MailDude.store.write(html_mail(html: '<p>Preview <b>body</b></p>'))
    expect(described_class.new(html_record).list_preview).to eq('Preview body')
  end

  it 'returns nil when mail parsing raises' do
    presenter = described_class.new(MailDude::MessageRecord.new(id: 'id', metadata: {}, raw_source: 'raw'))
    allow(Mail).to receive(:read_from_string).and_raise(StandardError)

    expect(presenter.mail).to be_nil
  end

  it 'uses decode fallback for broken parts and nil body values' do
    part = instance_double(Mail::Part)
    allow(part).to receive(:decoded).and_raise(Encoding::UndefinedConversionError)
    mail = instance_double(Mail::Message, multipart?: true, all_parts: [part])
    allow(part).to receive_messages(mime_type: 'text/plain', attachment?: false)
    presenter = described_class.new(MailDude::MessageRecord.new(id: 'id', metadata: {}, raw_source: 'raw'))
    allow(presenter).to receive(:mail).and_return(mail)

    expect(presenter.text_body).to eq(described_class::FALLBACK_DECODE_ERROR)
  end
end
