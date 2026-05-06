# frozen_string_literal: true

module MailDude
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    layout 'mail_dude/application'

    rescue_from AttachmentNotFoundError, MessageNotFoundError, with: :render_not_found
    rescue_from InvalidConfigurationError, StorageError, with: :render_storage_error

    private

    def render_not_found
      respond_to do |format|
        format.html { render 'mail_dude/messages/error', status: :not_found, locals: { message: 'Message not found.' } }
        format.any { head :not_found }
      end
    end

    def render_storage_error(error)
      diagnostic = Rails.env.production? ? 'MailDude storage is unavailable.' : error.message
      render 'mail_dude/messages/error', status: :internal_server_error, locals: { message: diagnostic }
    end
  end
end
