# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MailDude::AttachmentLocator do
  it 'finds standard and inline attachments with safe metadata' do
    record = MailDude.store.write(inline_image_mail)
    locator = described_class.new(record)
    attachment = locator.find('a0')

    expect(locator.attachments.length).to eq(1)
    expect(attachment.filename).to eq('logo.png')
    expect(attachment.content_type).to eq('image/png')
    expect(attachment.data).to include('PNGDATA')
    expect(attachment).to be_inline
    expect(locator.find_inline_by_cid('<logo@example.com>').id).to eq('a0')
    expect(locator.find_inline_by_cid('cid:missing')).to be_nil
  end

  it 'sanitizes filenames and applies fallbacks' do
    mail = attachment_mail(filename: '../bad/name.txt', content_type: nil)
    record = MailDude.store.write(mail)
    attachment = described_class.new(record).find('a0')

    expect(attachment.filename).to eq('.._bad_name.txt')
    expect(attachment.content_type).to eq('text/plain')
    expect(described_class.new(record).sanitize_filename('', fallback: 'attachment-a0')).to eq('attachment-a0')
    expect(described_class.new(record).sanitize_filename("bad\u0000name.txt",
                                                         fallback: 'fallback')).to eq('bad_name.txt')
  end

  it 'raises for missing, invalid, and disabled attachments' do
    record = MailDude.store.write(attachment_mail)
    locator = described_class.new(record)

    expect { locator.find('x1') }.to raise_error(MailDude::AttachmentNotFoundError)
    expect { locator.find('a9') }.to raise_error(MailDude::AttachmentNotFoundError)

    MailDude.configure do |config|
      config.storage = :memory
      config.capture_attachments = false
    end
    disabled_record = MailDude.store.write(attachment_mail)
    expect(described_class.new(disabled_record).attachments).to eq([])
    expect { described_class.new(disabled_record).find('a0') }.to raise_error(MailDude::AttachmentNotFoundError)
  end

  it 'returns no attachments for unparsable records and falls back for decode failures' do
    record = MailDude::MessageRecord.new(id: 'id', metadata: {}, raw_source: nil)
    expect(described_class.new(record).attachments).to eq([])

    part = instance_double(Mail::Part, decoded: nil, body: instance_double(Mail::Body, raw_source: 'RAW'))
    attachment = described_class::Attachment.new(id: 'a0', part: part,
                                                 metadata: { 'content_type' => 'application/octet' })
    allow(part).to receive(:decoded).and_raise(StandardError)
    expect(attachment.data).to eq('RAW')
  end

  it 'handles parser and decoded-size failures' do
    record = MailDude::MessageRecord.new(id: 'id', metadata: {}, raw_source: 'raw')
    allow(Mail).to receive(:read_from_string).and_raise(StandardError)
    expect(described_class.new(record).attachments).to eq([])

    body = instance_double(Mail::Body, raw_source: 'RAW-SIZE')
    part = instance_double(
      Mail::Part,
      multipart?: false,
      attachment?: true,
      filename: nil,
      content_disposition: nil,
      content_id: nil,
      mime_type: nil,
      body: body
    )
    allow(part).to receive(:decoded).and_raise(StandardError)
    mail = Mail.new
    allow(mail).to receive(:all_parts).and_return([part])

    attachment = described_class.new(mail).attachments.first

    expect(attachment.metadata['filename']).to eq('attachment-a0')
    expect(attachment.metadata['content_type']).to eq('application/octet-stream')
    expect(attachment.metadata['size_bytes']).to eq('RAW-SIZE'.bytesize)
  end
end
