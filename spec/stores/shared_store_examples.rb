# frozen_string_literal: true

RSpec.shared_examples 'a MailDude store' do
  it 'lists empty results with pagination defaults' do
    page = store.list(page: 'bad', per_page: 'bad')

    expect(page.records).to eq([])
    expect(page.total_pages).to eq(1)
    expect(page.page).to eq(1)
    expect(store.list(page: 0, per_page: 0).page).to eq(1)
    expect(store.prune(max_messages: nil, retention_period: nil)).to eq(0)
  end

  it 'writes, finds, orders, paginates, and searches messages' do
    travel_to(Time.utc(2026, 5, 6, 10)) { @first = store.write(plain_mail(subject: 'Alpha', to: 'a@example.com')) }
    travel_to(Time.utc(2026, 5, 6, 11)) { @second = store.write(plain_mail(subject: 'Beta', to: 'b@example.com')) }
    travel_to(Time.utc(2026, 5, 6, 12)) { @third = store.write(plain_mail(subject: 'Gamma', to: 'c@example.com')) }

    expect(store.find(@second.id).raw_source).to include('Beta')
    expect(store.list.records.map(&:id)).to eq([@third.id, @second.id])
    expect(store.list(page: 2).records.map(&:id)).to eq([@first.id])
    expect(store.list(query: 'alpha').records.map(&:id)).to eq([@first.id])
    expect(store.list(query: 'B@EXAMPLE.COM').records.map(&:id)).to eq([@second.id])
    expect(store.list(query: 'missing').records).to eq([])
  end

  it 'deletes, clears, and reports missing messages' do
    record = store.write(plain_mail)

    expect(store.delete(record.id)).to be(true)
    expect(store.delete(record.id)).to be(false)
    expect { store.find(record.id) }.to raise_error(MailDude::MessageNotFoundError)

    store.write(plain_mail(subject: 'One'))
    store.write(plain_mail(subject: 'Two'))
    expect(store.clear).to eq(2)
    expect(store.list.total_count).to eq(0)
  end

  it 'prunes by count, age, and their union' do
    travel_to(Time.utc(2026, 5, 1, 10)) { @old = store.write(plain_mail(subject: 'Old')) }
    travel_to(Time.utc(2026, 5, 6, 10)) { @middle = store.write(plain_mail(subject: 'Middle')) }
    travel_to(Time.utc(2026, 5, 7, 10)) { @new = store.write(plain_mail(subject: 'New')) }

    travel_to(Time.utc(2026, 5, 8, 10)) do
      expect(store.prune(max_messages: 2, retention_period: 3.days)).to eq(1)
      expect { store.find(@old.id) }.to raise_error(MailDude::MessageNotFoundError)
      expect(store.prune(max_messages: 1, retention_period: nil)).to eq(1)
      expect { store.find(@middle.id) }.to raise_error(MailDude::MessageNotFoundError)
      expect(store.find(@new.id)).to be_full
    end
  end

  it 'ignores corrupt captured_at values during pruning' do
    record = MailDude::MessageRecord.new(
      id: '20260506T143012123456Z-1111111111111111',
      metadata: { 'id' => '20260506T143012123456Z-1111111111111111', 'captured_at' => 'bad' },
      raw_source: 'Subject: Bad'
    )
    store.instance_variable_get(:@records)[record.id] = record if store.is_a?(MailDude::Stores::MemoryStore)

    expect(store.prune(max_messages: nil, retention_period: 1.day)).to eq(0)
  end

  it 'keeps attachment raw source retrievable' do
    record = store.write(attachment_mail)

    expect(MailDude::AttachmentLocator.new(store.find(record.id)).find('a0').data).to include('PDFDATA')
  end
end
