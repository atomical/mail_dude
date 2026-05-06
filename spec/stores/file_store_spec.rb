# frozen_string_literal: true

require 'rails_helper'
require_relative 'shared_store_examples'

RSpec.describe MailDude::Stores::FileStore do
  let(:path) { Pathname.new(Dir.mktmpdir('mail-dude')) }
  let(:store) { described_class.new(path) }

  after { FileUtils.rm_rf(path) }

  it_behaves_like 'a MailDude store'

  it 'creates the expected file layout and accepts string paths' do
    string_store = described_class.new(path.to_s)
    record = string_store.write(plain_mail)
    directory = path.join('messages', record.id)

    expect(path.join('.lock')).to exist
    expect(directory.join('metadata.json')).to exist
    expect(directory.join('message.eml')).to exist
    expect(JSON.parse(directory.join('metadata.json').read)['id']).to eq(record.id)
    expect(directory.join('message.eml').read).to include('Plain')
  end

  it 'uses unique IDs and protects against invalid paths' do
    records = 3.times.map { store.write(plain_mail) }

    expect(records.map(&:id).uniq.length).to eq(3)
    expect { store.find('../secret') }.to raise_error(MailDude::MessageNotFoundError)
    expect { store.find('%2e%2e') }.to raise_error(MailDude::MessageNotFoundError)
    expect { store.delete('/absolute/path') }.to raise_error(MailDude::MessageNotFoundError)
  end

  it 'skips corrupt metadata and raises when raw files are missing' do
    record = store.write(plain_mail)
    path.join('messages', record.id, 'metadata.json').write('{bad')

    expect(store.list.records).to eq([])
    expect { store.find(record.id) }.to raise_error(MailDude::MessageNotFoundError)

    other = store.write(plain_mail)
    path.join('messages', other.id, 'message.eml').delete
    expect { store.find(other.id) }.to raise_error(MailDude::MessageNotFoundError)
  end

  it 'lists no records when the messages directory is missing' do
    store
    FileUtils.rm_rf(path.join('messages'))

    expect(store.list.records).to eq([])
  end

  it 'handles concurrent writes' do
    threads = 5.times.map { Thread.new { store.write(plain_mail).id } }
    ids = threads.map(&:value)

    expect(ids.uniq.length).to eq(5)
    expect(store.list(per_page: 10).total_count).to eq(5)
  end
end
