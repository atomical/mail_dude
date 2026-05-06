# frozen_string_literal: true

module MailDude
  class AttachmentsController < ApplicationController
    SAFE_INLINE_TYPES = %w[image/gif image/jpeg image/png image/webp image/svg+xml].freeze

    def show
      record = MailDude.store.find(params[:message_id] || params[:id])
      attachment = AttachmentLocator.new(record).find(params[:attachment_id])
      send_data attachment.data,
                filename: attachment.filename,
                type: attachment.content_type,
                disposition: disposition_for(attachment)
    end

    private

    def disposition_for(attachment)
      if params[:inline] == '1' && attachment.inline? && SAFE_INLINE_TYPES.include?(attachment.content_type)
        return 'inline'
      end

      'attachment'
    end
  end
end
