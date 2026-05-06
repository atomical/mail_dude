# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MailDude::ApplicationHelper, type: :helper do
  it 'formats empty address lists and selected state' do
    message = MailDude::MessageRecord.new(id: 'id', metadata: {})

    expect(helper.mail_dude_address_list([])).to eq('None')
    expect(helper.mail_dude_selected?(message)).to be(false)

    assign(:selected_message, message)
    expect(helper.mail_dude_address_list(['a@example.com'])).to eq('a@example.com')
    expect(helper.mail_dude_selected?(message)).to be(true)
  end
end
