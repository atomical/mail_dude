# frozen_string_literal: true

module MailDude
  class AttachmentLocator
    class << self
      def attachment_part?(part)
        !part.multipart? && (part.attachment? || part.filename.present? || inline_renderable_part?(part))
      end

      def content_disposition(part)
        part.content_disposition.to_s.split(';').first.to_s.downcase
      end

      def inline_renderable_part?(part)
        inline_part?(part) || part.content_id.present?
      end

      private

      def inline_part?(part)
        content_disposition(part) == 'inline' && part.content_id.present?
      end
    end

    Attachment = Struct.new(:id, :part, :metadata, keyword_init: true) do
      def content_type
        metadata['content_type']
      end

      def data
        part.decoded
      rescue StandardError
        part.body.raw_source.to_s
      end

      def filename
        metadata['filename']
      end

      def inline?
        metadata['inline']
      end
    end

    def initialize(message)
      @message = message
    end

    def attachments
      return [] unless MailDude.configuration.capture_attachments

      attachment_parts.each_with_index.map do |part, index|
        id = "a#{index}"
        Attachment.new(id: id, part: part, metadata: metadata_for(part, id))
      end
    end

    def attachments_count
      attachment_parts.length
    end

    def attachments_present?
      attachments_count.positive?
    end

    def find(attachment_id)
      raise AttachmentNotFoundError, 'Attachment not found' unless attachment_id.to_s.match?(/\Aa\d+\z/)

      attachments.find { |attachment| attachment.id == attachment_id.to_s } ||
        raise(AttachmentNotFoundError, 'Attachment not found')
    end

    def find_inline_by_cid(content_id)
      normalized = normalize_content_id(content_id)
      return nil if normalized.blank?

      attachments.find { |attachment| attachment.metadata['content_id'] == normalized }
    end

    def normalize_content_id(content_id)
      content_id.to_s.delete_prefix('cid:').delete_prefix('<').delete_suffix('>').strip
    end

    def sanitize_filename(filename, fallback:)
      sanitized = filename.to_s.encode('UTF-8', invalid: :replace, undef: :replace)
      sanitized = sanitized.gsub(%r{[/\\\0[:cntrl:]]}, '_').strip
      sanitized.presence || fallback
    end

    private

    attr_reader :message

    def attachment_parts
      return [] unless mail

      mail.all_parts.select { |part| self.class.attachment_part?(part) }
    end

    def mail
      @mail ||=
        if message.is_a?(Mail::Message)
          message
        elsif message.raw_source.present?
          Mail.read_from_string(message.raw_source)
        end
    rescue StandardError
      nil
    end

    def metadata_for(part, id)
      {
        'id' => id,
        'filename' => sanitize_filename(part.filename, fallback: "attachment-#{id}"),
        'content_type' => part.mime_type.presence || 'application/octet-stream',
        'content_id' => normalize_content_id(part.content_id),
        'disposition' => self.class.content_disposition(part).presence || 'attachment',
        'inline' => self.class.inline_renderable_part?(part),
        'size_bytes' => decoded_size(part)
      }
    end

    def decoded_size(part)
      part.decoded.to_s.bytesize
    rescue StandardError
      part.body.raw_source.to_s.bytesize
    end
  end
end
