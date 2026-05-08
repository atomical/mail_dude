# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MailDude::Engine.routes, type: :routing do
  routes { MailDude::Engine.routes }

  it 'routes all engine endpoints' do
    expect(get: '/').to route_to('mail_dude/messages#index')
    expect(get: '/messages').to route_to('mail_dude/messages#index')
    expect(get: '/messages/abc').to route_to('mail_dude/messages#show', id: 'abc')
    expect(get: '/messages/abc/html').to route_to('mail_dude/messages#html', id: 'abc')
    expect(get: '/messages/abc/text').to route_to('mail_dude/messages#text', id: 'abc')
    expect(get: '/messages/abc/headers').to route_to('mail_dude/messages#message_headers', id: 'abc')
    expect(get: '/messages/abc/raw').to route_to('mail_dude/messages#raw', id: 'abc')
    expect(get: '/messages/abc/attachments/a0').to route_to(
      'mail_dude/attachments#show',
      id: 'abc',
      attachment_id: 'a0'
    )
    expect(delete: '/messages/abc').to route_to('mail_dude/messages#destroy', id: 'abc')
    expect(delete: '/messages/clear').to route_to('mail_dude/messages#clear')
  end
end
