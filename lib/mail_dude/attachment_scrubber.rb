# frozen_string_literal: true

module MailDude
  class AttachmentScrubber
    RAW_SOURCE_OMITTED = "MailDude omitted raw message source because attachment capture is disabled.\n"

    def initialize(mail)
      @mail = mail
    end

    def raw_source
      source = mail&.to_s
      return RAW_SOURCE_OMITTED if source.blank?

      sanitized = Mail.read_from_string(source)
      remove_attachments!(sanitized)
      sanitized.to_s
    rescue StandardError
      RAW_SOURCE_OMITTED
    end

    private

    attr_reader :mail

    def remove_attachments!(message)
      return remove_single_part_attachment!(message) unless message.multipart?

      message.parts.recursive_delete_if { |part| AttachmentLocator.attachment_part?(part) }
    end

    def remove_single_part_attachment!(message)
      message.body = '' if AttachmentLocator.attachment_part?(message)
    end
  end
end
