# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MailDude::HtmlBodyRenderer do
  it 'renders a placeholder for missing HTML' do
    record = MailDude.store.write(plain_mail)
    renderer = described_class.new(MailDude::MessagePresenter.new(record), attachment_url: ->(*) { '/unused' })

    expect(renderer.render).to include('does not include an HTML body')
  end

  it 'rewrites cid images and makes links safe' do
    record = MailDude.store.write(inline_image_mail)
    renderer = described_class.new(
      MailDude::MessagePresenter.new(record),
      attachment_url: ->(id, inline:) { "/mail_dude/messages/#{record.id}/attachments/#{id}?inline=#{inline}" }
    )

    html = renderer.render

    expect(html).to include('/attachments/a0?inline=true')
    expect(html).to include('target="_blank"')
    expect(html).to include('noopener noreferrer')
  end

  it 'leaves unknown cids and invalid HTML safe to render in the iframe endpoint' do
    record = MailDude.store.write(html_mail(html: '<img src="cid:missing"><script>alert(1)</script><a>plain'))
    renderer = described_class.new(MailDude::MessagePresenter.new(record), attachment_url: ->(*) { '/unused' })

    expect(renderer.render).to include('cid:missing')
    expect(renderer.render).to include('<script>')
  end

  it 'falls back to the original HTML if rewriting fails' do
    record = MailDude.store.write(inline_image_mail)
    renderer = described_class.new(MailDude::MessagePresenter.new(record), attachment_url: lambda { |*|
      raise StandardError
    })

    expect(renderer.render).to include('cid:logo@example.com')
  end
end
