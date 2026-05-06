# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MailDude attachments', type: :request do
  it 'downloads attachments with safe headers and serves inline images for cid rendering' do
    record = MailDude.store.write(inline_image_mail)

    get "/mail_dude/messages/#{record.id}/attachments/a0"
    expect(response).to have_http_status(:ok)
    expect(response.headers['Content-Disposition']).to include('attachment')
    expect(response.headers['Content-Type']).to include('image/png')
    expect(response.body).to include('PNGDATA')

    get "/mail_dude/messages/#{record.id}/attachments/a0", params: { inline: '1' }
    expect(response.headers['Content-Disposition']).to include('inline')
  end

  it 'returns 404 for missing messages, missing attachments, and disabled attachments' do
    record = MailDude.store.write(attachment_mail)

    get '/mail_dude/messages/bad-id/attachments/a0'
    expect(response).to have_http_status(:not_found)

    get "/mail_dude/messages/#{record.id}/attachments/a9"
    expect(response).to have_http_status(:not_found)

    MailDude.configure do |config|
      config.storage = :memory
      config.capture_attachments = false
    end
    disabled = MailDude.store.write(attachment_mail)
    get "/mail_dude/messages/#{disabled.id}/attachments/a0"
    expect(response).to have_http_status(:not_found)
  end
end
