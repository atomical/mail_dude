# frozen_string_literal: true

module MailDude
  class MessagePresenter
    FALLBACK_DECODE_ERROR = 'Unable to decode this message part.'

    attr_reader :record

    delegate :id, to: :record

    def initialize(record)
      @record = record
    end

    def subject
      metadata_value('subject').to_s
    end

    def subject_label
      subject.strip.presence || '(no subject)'
    end

    def captured_at
      Time.iso8601(metadata_value('captured_at').to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def captured_at_label
      captured_at ? captured_at.strftime('%Y-%m-%d %H:%M:%S UTC') : '(unknown time)'
    end

    def from = metadata_array('from')
    def sender = metadata_array('sender')
    def to = metadata_array('to')
    def cc = metadata_array('cc')
    def bcc = metadata_array('bcc')
    def reply_to = metadata_array('reply_to')
    def message_id = metadata_value('message_id')
    def mailer = metadata_value('mailer')
    def mailer_action = metadata_value('mailer_action')
    def content_type = metadata_value('content_type')
    def size_bytes = metadata_value('size_bytes').to_i
    def raw_source = record.raw_source.to_s
    def attachments = metadata_array('attachments')

    def mailer_label
      return '(unknown mailer)' if mailer.blank? && mailer_action.blank?
      return mailer if mailer_action.blank?
      return "##{mailer_action}" if mailer.blank?

      "#{mailer}##{mailer_action}"
    end

    def size_label
      bytes = size_bytes
      return "#{bytes} B" if bytes < 1.kilobyte
      return "#{format('%.1f', bytes / 1.kilobyte.to_f)} KB" if bytes < 1.megabyte

      "#{format('%.1f', bytes / 1.megabyte.to_f)} MB"
    end

    def mail
      @mail ||= raw_source.present? ? Mail.read_from_string(raw_source) : nil
    rescue StandardError
      nil
    end

    def html_body
      decoded_body_for('text/html')
    end

    def text_body
      decoded_body_for('text/plain')
    end

    def raw_headers
      return '' if raw_source.blank?

      raw_source.split(/\r?\n\r?\n/, 2).first.to_s
    end

    def has_attachments? = metadata_value('has_attachments') == true || attachments.any?

    def attachment_count = metadata_value('attachments_count').presence&.to_i || attachments.length

    def attachment_count_label
      count = attachment_count
      "#{count} #{'attachment'.pluralize(count)}"
    end

    def recipient_summary
      to.first.presence || cc.first.presence || bcc.first.presence || '(no recipients)'
    end

    def sender_summary
      from.first.presence || sender.first.presence || '(unknown sender)'
    end

    def list_preview
      preview = text_body.presence || ActionView::Base.full_sanitizer.sanitize(html_body.to_s)
      preview.to_s.squish.truncate(140)
    end

    private

    def decoded_body_for(mime_type)
      part = body_part(mime_type)
      return nil unless part

      decode_part(part)
    end

    def body_part(mime_type)
      return nil unless mail
      return mail if !mail.multipart? && mail.mime_type == mime_type

      mail.all_parts.find { |part| part.mime_type == mime_type && !part.attachment? }
    end

    def decode_part(part)
      decoded = part.decoded
      decoded.to_s.encode('UTF-8', invalid: :replace, undef: :replace)
    rescue StandardError
      FALLBACK_DECODE_ERROR
    end

    def metadata_array(key)
      Array(metadata_value(key)).compact
    end

    def metadata_value(key)
      record.metadata[key]
    end
  end
end
