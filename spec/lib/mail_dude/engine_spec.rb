# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MailDude::Engine do
  describe 'asset initializer' do
    it 'adds the engine stylesheet to Sprockets precompile assets' do
      precompile = []
      assets = Struct.new(:precompile).new(precompile)
      config = Struct.new(:assets).new(assets)
      app = Struct.new(:config).new(config)

      run_initializer('mail_dude.assets', app)

      expect(precompile).to include(*described_class::ASSET_PRECOMPILE)
    end

    it 'skips apps without Sprockets assets configuration' do
      app = Struct.new(:config).new(Object.new)

      expect { run_initializer('mail_dude.assets', app) }.not_to raise_error
    end

    def run_initializer(name, app)
      described_class.initializers.find { |initializer| initializer.name == name }.run(app)
    end
  end
end
