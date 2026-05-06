# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MailDude::MessageRecord do
  it 'stringifies metadata keys and reports whether raw source is loaded' do
    partial = described_class.new(id: 'id', metadata: { subject: 'Hi' })
    full = described_class.new(id: 'id', metadata: { subject: 'Hi' }, raw_source: 'Subject: Hi')

    expect(partial.metadata['subject']).to eq('Hi')
    expect(partial).not_to be_full
    expect(full).to be_full
  end
end
