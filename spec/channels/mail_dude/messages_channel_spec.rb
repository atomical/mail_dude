# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MailDude::MessagesChannel, type: :channel do
  it 'rejects subscriptions when live updates are disabled' do
    subscribe

    expect(subscription).to be_rejected
  end

  it 'rejects subscriptions when the authorizer denies the connection' do
    MailDude.configure do |config|
      config.storage = :memory
      config.live_updates = true
      config.live_update_authorizer = ->(_connection) { false }
    end

    subscribe

    expect(subscription).to be_rejected
  end

  it 'streams from the configured stream when the authorizer allows the connection' do
    user = Object.new
    stub_connection current_user: user
    MailDude.configure do |config|
      config.storage = :memory
      config.live_updates = true
      config.live_update_stream_name = 'mail_dude:test:authorized'
      config.live_update_authorizer = ->(connection) { connection.current_user == user }
    end

    subscribe

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from('mail_dude:test:authorized')
  end
end
