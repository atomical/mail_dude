# frozen_string_literal: true

require 'rails_helper'
require_relative 'shared_store_examples'

RSpec.describe MailDude::Stores::DatabaseStore do
  let(:store) { described_class.new }

  before { create_mail_dude_table! }

  it_behaves_like 'a MailDude store'

  it 'writes indexed fields and raw binary storage' do
    record = store.write(plain_mail(subject: 'Database'))
    row = MailDude::StoredEmail.find_by!(uid: record.id)

    expect(row.subject).to eq('Database')
    expect(row.raw_message).to include('Database')
    expect(JSON.parse(row.to_json)).to include('uid' => record.id)
  end

  it 'raises a helpful storage error when the table is missing' do
    drop_mail_dude_table!

    expect { store.write(plain_mail) }.to raise_error(MailDude::StorageError, /db:migrate/)
    expect { store.list }.to raise_error(MailDude::StorageError, /db:migrate/)
  end

  it 'wraps Active Record write failures in StorageError' do
    allow(MailDude::StoredEmail).to receive(:create!).and_raise(ActiveRecord::StatementInvalid, 'boom')

    expect { store.write(plain_mail) }.to raise_error(MailDude::StorageError, /boom/)
  end
end
