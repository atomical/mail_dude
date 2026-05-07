# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MailDude messages', type: :request do
  it 'renders empty inbox and search empty state' do
    get '/mail_dude'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('class="mail-dude-logo"')
    expect(response.body).to include('mail_dude/icon')
    expect(response.body).to include('No captured messages yet.')
    expect(response.body).not_to include('MailDude::MessagesChannel')

    get '/mail_dude/messages', params: { q: 'missing' }
    expect(response.body).to include('No messages match your search.')
  end

  it 'renders the live update banner and subscription script when enabled' do
    MailDude.configure do |config|
      config.storage = :memory
      config.live_updates = true
    end

    get '/mail_dude'

    expect(response.body).to include('data-mail-dude-live-banner')
    expect(response.body).to include('data-mail-dude-message-list')
    expect(response.body).to include('data-mail-dude-live-list-enabled="true"')
    expect(response.body).to include('MailDude::MessagesChannel')
    expect(response.body).to include('action-cable-url')
  end

  it 'renders list, selected pane, metadata, pagination, and iframe' do
    first = MailDude.store.write(plain_mail(subject: 'First'))
    second = MailDude.store.write(inline_image_mail)
    MailDude.store.write(plain_mail(subject: 'Third'))

    get "/mail_dude/messages/#{second.id}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('MailDude', 'Inline', 'From', 'Message-ID')
    expect(response.body).to include('sandbox=""')
    expect(response.body).not_to include('allow-scripts')
    expect(response.body).to include('Next').or include('Previous')
    expect(response.body).to include('data-mail-dude-message-id')
    expect(response.body).to include(first.id).or include('Page 1 of 2')
  end

  it 'supports search, body endpoints, raw source, delete, clear, and missing responses' do
    record = MailDude.store.write(alternative_mail)

    get '/mail_dude/messages', params: { q: 'alternative' }
    expect(response.body).to include('Alternative')

    get "/mail_dude/messages/#{record.id}/html"
    expect(response.headers['Content-Security-Policy']).to include("script-src 'none'")
    expect(response.body).to include('HTML body')

    inline = MailDude.store.write(inline_image_mail)
    get "/mail_dude/messages/#{inline.id}/html"
    expect(response.body).to include('/attachments/a0?inline=1')

    get "/mail_dude/messages/#{record.id}/text"
    expect(response.body).to include('Plain body')

    get "/mail_dude/messages/#{record.id}/headers"
    expect(response.body).to include('Subject: Alternative')

    get "/mail_dude/messages/#{record.id}/raw"
    expect(response.media_type).to eq('text/plain')
    expect(response.body).to include('Alternative')

    delete "/mail_dude/messages/#{record.id}"
    expect(response).to redirect_to('/mail_dude/messages')

    delete "/mail_dude/messages/#{record.id}"
    expect(response).to have_http_status(:not_found)

    MailDude.store.write(plain_mail)
    delete '/mail_dude/messages/clear'
    expect(response).to redirect_to('/mail_dude/messages')
    expect(MailDude.store.list.total_count).to eq(0)
  end

  it 'returns safe placeholders and 404s without exposing paths' do
    record = MailDude.store.write(plain_mail)

    get "/mail_dude/messages/#{record.id}/html"
    expect(response.body).to include('does not include an HTML body')

    get "/mail_dude/messages/#{record.id}/text"
    expect(response.body).to include('Hello from MailDude')

    get '/mail_dude/messages/bad-id'
    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include(Rails.root.to_s)
  end

  it 'renders storage diagnostics outside production' do
    allow(MailDude).to receive(:store).and_raise(MailDude::StorageError, 'diagnostic')

    get '/mail_dude/messages'

    expect(response).to have_http_status(:internal_server_error)
    expect(response.body).to include('diagnostic')
  end

  it 'hides storage diagnostics in production' do
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(MailDude).to receive(:store).and_raise(MailDude::StorageError, 'diagnostic')

    get '/mail_dude/messages'

    expect(response).to have_http_status(:internal_server_error)
    expect(response.body).to include('MailDude storage is unavailable.')
    expect(response.body).not_to include('diagnostic')
  end
end
