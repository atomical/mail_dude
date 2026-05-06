# frozen_string_literal: true

require 'rails_helper'
require_relative 'shared_store_examples'

RSpec.describe MailDude::Stores::MemoryStore do
  let(:store) { described_class.new }

  it_behaves_like 'a MailDude store'

  it 'raises for invalid IDs' do
    expect { store.find('../secret') }.to raise_error(MailDude::MessageNotFoundError)
    expect { store.delete('/absolute/path') }.to raise_error(MailDude::MessageNotFoundError)
  end
end
