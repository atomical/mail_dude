# frozen_string_literal: true

module MailDude
  class MessagesController < ApplicationController
    before_action :load_page, only: %i[index show]

    def index
      @selected_message = first_message
    end

    def show
      @selected_message = MailDude.store.find(params[:id])
      render :index
    end

    def html
      presenter = presenter_for(params[:id])
      response.headers['Content-Security-Policy'] =
        "default-src 'none'; img-src 'self' data:; style-src 'unsafe-inline'; font-src data:; " \
        "base-uri 'none'; form-action 'none'; script-src 'none'"
      render html: renderer_for(presenter).render.html_safe, layout: false
    end

    def text
      render plain: presenter_for(params[:id]).text_body.presence || 'This message does not include a plain text body.'
    end

    def message_headers
      render plain: presenter_for(params[:id]).raw_headers.presence || 'This message does not include headers.'
    end

    def raw
      record = MailDude.store.find(params[:id])
      response.headers['Content-Disposition'] = %(inline; filename="#{record.id}.eml")
      render plain: record.raw_source, content_type: 'text/plain'
    end

    def destroy
      raise MessageNotFoundError, 'Message not found' unless MailDude.store.delete(params[:id])

      redirect_to messages_path, notice: 'Message deleted.'
    end

    def clear
      count = MailDude.store.clear
      redirect_to messages_path, notice: "#{count} messages cleared."
    end

    private

    def first_message
      first_record = @page.records.first
      first_record ? MailDude.store.find(first_record.id) : nil
    end

    def load_page
      @query = params[:q]
      @page = MailDude.store.list(page: params[:page], per_page: params[:per_page], query: @query)
    end

    def presenter_for(id)
      MessagePresenter.new(MailDude.store.find(id))
    end

    def renderer_for(presenter)
      HtmlBodyRenderer.new(presenter,
                           attachment_url: lambda do |attachment_id, **|
                             attachment_message_path(presenter.id, attachment_id, inline: '1')
                           end)
    end
  end
end
