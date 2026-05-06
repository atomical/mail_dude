# frozen_string_literal: true

module MailDude
  class MessagesChannel < ActionCable::Channel::Base
    def subscribed
      return reject unless authorized?

      stream_from MailDude.configuration.live_update_stream_name
    end

    private

    def authorized?
      MailDude.configuration.live_updates &&
        MailDude.configuration.live_update_authorizer.call(connection)
    end
  end
end
