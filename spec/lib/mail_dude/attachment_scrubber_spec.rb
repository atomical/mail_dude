# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MailDude::AttachmentScrubber do
  it 'removes multipart attachment data while preserving message body text' do
    raw_source = described_class.new(attachment_mail).raw_source

    expect(raw_source).to include('Hello from MailDude')
    expect(raw_source).not_to include('PDFDATA')
    expect(raw_source).not_to include('UERGREFUQQ==')
  end

  it 'removes single-part attachment data' do
    single_part_attachment = Mail.new do
      content_type 'image/png'
      content_disposition 'attachment; filename=logo.png'
      body 'PNGDATA'
    end

    expect(described_class.new(single_part_attachment).raw_source).not_to include('PNGDATA')
  end

  it 'preserves single-part non-attachment body content' do
    expect(described_class.new(html_mail(html: '<p>HTML</p>')).raw_source).to include('<p>HTML</p>')
  end

  it 'fails closed when raw source cannot be sanitized' do
    allow(Mail).to receive(:read_from_string).and_raise(StandardError)

    expect(described_class.new(attachment_mail).raw_source).to include('omitted raw message source')
    expect(described_class.new(nil).raw_source).to include('omitted raw message source')
  end
end
