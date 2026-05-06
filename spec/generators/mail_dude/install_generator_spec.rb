# frozen_string_literal: true

require 'rails_helper'
require 'rails/generators/testing/behavior'
require 'generators/mail_dude/install_generator'

RSpec.describe MailDude::Generators::InstallGenerator, type: :generator do
  include Rails::Generators::Testing::Behavior
  include FileUtils

  tests described_class
  destination File.expand_path('../../tmp/generators', __dir__)

  before { prepare_destination }

  it 'creates the default file-storage initializer and prints snippets' do
    run_generator
    output = capture(:stdout) { described_class.new.print_next_steps }
    initializer = file('config/initializers/mail_dude.rb')

    expect(initializer).to exist
    expect(initializer.read).to include('config.storage = :file')
    expect(initializer.read).to include('config.live_updates = false')
    expect(initializer.read).to include('config.live_update_authorizer = ->(_connection) { false }')
    expect(output).to include('mount MailDude::Engine, at: "/mail_dude"')
    expect(output).to include('config.action_mailer.delivery_method = :mail_dude')
    expect(output).to include('Do not expose /mail_dude publicly')
  end

  it 'supports database storage and migration copying' do
    run_generator ['--database']
    generator = described_class.new
    allow(generator).to receive(:options).and_return({ database: true })
    output = capture(:stdout) { generator.print_next_steps }

    expect(file('config/initializers/mail_dude.rb').read).to include('config.storage = :database')
    expect(Dir[File.join(destination_root, 'db/migrate/*create_mail_dude_stored_emails.rb')]).not_to be_empty
    expect(output).to include('bin/rails db:migrate')
  end

  def file(path)
    Pathname.new(File.join(destination_root, path))
  end
end
