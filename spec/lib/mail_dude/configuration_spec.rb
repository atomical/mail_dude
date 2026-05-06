# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MailDude::Configuration do
  it 'sets safe defaults' do
    config = described_class.new

    expect(config.enabled_environments).to eq(%w[development qa test])
    expect(config.storage).to eq(:file)
    expect(config.storage_path.to_s).to end_with('tmp/mail_dude')
    expect(config.max_messages).to eq(1_000)
    expect(config.retention_period).to eq(7.days)
    expect(config.max_message_size).to eq(25.megabytes)
    expect(config.allow_production).to be(false)
    expect(config.capture_attachments).to be(true)
    expect(config.capture_mailer_metadata_headers).to be(true)
    expect(config.default_per_page).to eq(50)
    expect(config.live_updates).to be(false)
    expect(config.live_update_stream_name).to eq('mail_dude:test:messages')
    expect(config.live_update_authorizer.call(Object.new)).to be(false)
  end

  it 'falls back to Dir.tmpdir when Rails.root is unavailable' do
    allow(Rails).to receive(:root).and_return(nil)

    expect(described_class.new.storage_path.to_s).to eq(Pathname.new(Dir.tmpdir).join('mail_dude').to_s)
  end

  it 'normalizes custom values and validates them' do
    config = described_class.new
    config.enabled_environments = :test
    config.storage = 'memory'
    config.max_messages = nil
    config.retention_period = nil
    config.max_message_size = nil

    expect(config.validate!).to eq(config)
    expect(config.enabled_environments).to eq(['test'])
    expect(config.storage).to eq(:memory)
  end

  it 'defaults the live update stream without Rails env' do
    allow(Rails).to receive(:env).and_return(nil)
    stub_const('ENV', { 'RAILS_ENV' => 'qa' })

    expect(described_class.new.live_update_stream_name).to eq('mail_dude:qa:messages')
  end

  it 'rejects invalid configuration values' do
    expect { invalid_config(storage: :redis) }.to raise_error(MailDude::InvalidConfigurationError, /storage/)
    expect { invalid_config(storage: Object.new) }.to raise_error(MailDude::InvalidConfigurationError, /storage/)
    expect { invalid_config(storage_path: '') }.to raise_error(MailDude::InvalidConfigurationError, /storage_path/)
    expect { invalid_config(max_messages: 0) }.to raise_error(MailDude::InvalidConfigurationError, /max_messages/)
    expect do
      invalid_config(retention_period: -1.day)
    end.to raise_error(MailDude::InvalidConfigurationError, /retention_period/)
    expect do
      invalid_config(max_message_size: 0)
    end.to raise_error(MailDude::InvalidConfigurationError, /max_message_size/)
    expect do
      invalid_config(default_per_page: 'many')
    end.to raise_error(MailDude::InvalidConfigurationError, /default_per_page/)
    expect do
      invalid_config(live_update_stream_name: '')
    end.to raise_error(MailDude::InvalidConfigurationError, /live_update_stream_name/)
    expect do
      invalid_config(live_update_authorizer: true)
    end.to raise_error(MailDude::InvalidConfigurationError, /live_update_authorizer/)
  end

  it 'supports MailDude module configuration, enabled checks, resets, and store factories' do
    MailDude.configure { |config| config.storage = :memory }
    expect(MailDude.enabled?('test')).to be(true)
    expect(MailDude.enabled?('staging')).to be(false)
    expect(MailDude.enabled?('production')).to be(false)

    MailDude.configure do |config|
      config.allow_production = true
      config.storage = :memory
    end
    expect(MailDude.enabled?('production')).to be(true)
    expect(MailDude.store).to be_a(MailDude::Stores::MemoryStore)

    MailDude.configure { |config| config.storage = :file }
    expect(MailDude.store).to be_a(MailDude::Stores::FileStore)

    create_mail_dude_table!
    MailDude.configure { |config| config.storage = :database }
    expect(MailDude.store).to be_a(MailDude::Stores::DatabaseStore)

    expect(MailDude.rails_environment).to eq('test')
    allow(Rails).to receive(:env).and_return(nil)
    stub_const('ENV', { 'RACK_ENV' => 'rack-test' })
    expect(MailDude.rails_environment).to eq('rack-test')
    MailDude.reset_configuration!
    expect(MailDude.configuration.storage).to eq(:file)
  end

  def invalid_config(attributes)
    config = described_class.new
    attributes.each { |key, value| config.public_send("#{key}=", value) }
    config.validate!
  end
end
