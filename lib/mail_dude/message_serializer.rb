# frozen_string_literal: true

module MailDude
  class MessageSerializer
    INTERNAL_MAILER_HEADER = 'X-Mail-Dude-Mailer'
    INTERNAL_ACTION_HEADER = 'X-Mail-Dude-Action'

    attr_reader :captured_at, :id, :mail, :raw_source

    def initialize(mail, id:, captured_at:, raw_source: nil)
      @mail = mail
      @id = id
      @captured_at = captured_at.utc
      @raw_source = raw_source || mail.to_s
    end

    def metadata
      {
        'id' => id,
        'captured_at' => captured_at.iso8601(6),
        'subject' => decoded_subject,
        'from' => addresses(:from),
        'sender' => addresses(:sender),
        'to' => addresses(:to),
        'cc' => addresses(:cc),
        'bcc' => addresses(:bcc),
        'reply_to' => addresses(:reply_to),
        'date' => date_value,
        'message_id' => header_value(:message_id),
        'in_reply_to' => header_value(:in_reply_to),
        'references' => references,
        'content_type' => content_type,
        'mime_version' => header_value(:mime_version),
        'mailer' => internal_header(INTERNAL_MAILER_HEADER),
        'mailer_action' => internal_header(INTERNAL_ACTION_HEADER),
        'has_html' => part_present?('text/html'),
        'has_text' => part_present?('text/plain'),
        'has_attachments' => attachment_locator.attachments_present?,
        'attachments_count' => attachment_locator.attachments_count,
        'attachments' => attachments,
        'size_bytes' => raw_source.bytesize
      }
    end

    private

    def addresses(field_name)
      field = mail[field_name]
      return [] unless field

      field.addrs.map { |address| format_address(address) }.compact
    rescue StandardError
      fallback = field.to_s.strip
      fallback.present? ? [fallback] : []
    end

    def attachments
      @attachments ||= attachment_locator.attachments.map(&:metadata)
    end

    def attachment_locator
      @attachment_locator ||= AttachmentLocator.new(mail)
    end

    def content_type
      mail.mime_type.presence || mail.content_type.to_s.split(';').first.presence
    end

    def date_value
      date = mail.date
      return nil unless date

      date.to_time.utc.iso8601
    rescue StandardError
      nil
    end

    def decoded_subject
      mail.subject
    rescue StandardError
      mail[:subject].to_s
    end

    def format_address(address)
      display = address.display_name.to_s
      email = address.address.to_s
      return email if display.blank?
      return display if email.blank?

      "#{display} <#{email}>"
    end

    def header_value(field_name)
      value = mail.public_send(field_name)
      value.respond_to?(:value) ? value.value : value
    rescue StandardError
      nil
    end

    def internal_header(name)
      mail[name]&.decoded
    rescue StandardError
      nil
    end

    def part_present?(mime_type)
      if mail.multipart?
        mail.all_parts.any? { |part| part.mime_type == mime_type && !part.attachment? }
      else
        mail.mime_type == mime_type
      end
    end

    def references
      raw = mail.references
      Array(raw).flat_map { |value| value.to_s.split(/\s+/) }.compact_blank
    rescue StandardError
      []
    end
  end
end
