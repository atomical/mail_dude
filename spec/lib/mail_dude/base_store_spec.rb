# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MailDude::Stores::Base do
  it 'defines the required abstract adapter interface' do
    base = described_class.new

    expect { base.write(plain_mail) }.to raise_error(NotImplementedError)
    expect { base.list }.to raise_error(NotImplementedError)
    expect { base.find('id') }.to raise_error(NotImplementedError)
    expect { base.delete('id') }.to raise_error(NotImplementedError)
    expect { base.clear }.to raise_error(NotImplementedError)
    expect { base.prune }.to raise_error(NotImplementedError)
  end
end
