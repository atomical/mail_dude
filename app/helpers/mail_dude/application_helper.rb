# frozen_string_literal: true

module MailDude
  module ApplicationHelper
    def mail_dude_address_list(values)
      Array(values).presence&.join(', ') || 'None'
    end

    def mail_dude_selected?(message)
      @selected_message&.id == message.id
    end
  end
end
