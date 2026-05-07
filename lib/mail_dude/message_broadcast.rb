# frozen_string_literal: true

module MailDude
  class MessageBroadcast
    def self.broadcast(record)
      new(record).broadcast
    end

    def initialize(record)
      @record = record
    end

    def broadcast
      return false unless MailDude.configuration.live_updates
      return false unless action_cable_server

      action_cable_server.broadcast(MailDude.configuration.live_update_stream_name, payload)
      true
    end

    private

    attr_reader :record

    def action_cable_server
      ActionCable.server if defined?(ActionCable)
    end

    def payload
      presenter = MessagePresenter.new(record)
      {
        event: 'message_created',
        id: record.id,
        **list_metadata(presenter)
      }
    end

    def list_metadata(presenter)
      {
        subject: presenter.subject_label,
        sender: presenter.sender_summary,
        recipients: presenter.recipient_summary,
        captured_at: presenter.captured_at_label,
        attachments_count: presenter.attachments.length,
        attachment_count_label: presenter.attachment_count_label,
        mailer_label: presenter.mailer_label
      }
    end
  end
end
