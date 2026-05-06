# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MailDude::Page do
  it 'normalizes invalid input and computes navigation' do
    page = described_class.new(records: %w[a b], page: 'bad', per_page: 0, total_count: 5)

    expect(page.page).to eq(1)
    expect(page.per_page).to eq(2)
    expect(page.total_pages).to eq(3)
    expect(page.next_page).to eq(2)
    expect(page.previous_page).to be_nil
  end

  it 'keeps total pages at least one and exposes previous pages' do
    page = described_class.new(records: [], page: 2, per_page: 10, total_count: 0)

    expect(page.total_pages).to eq(1)
    expect(page.next_page).to be_nil
    expect(page.previous_page).to eq(1)
  end
end
