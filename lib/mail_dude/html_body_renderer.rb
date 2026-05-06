# frozen_string_literal: true

require 'nokogiri'

module MailDude
  class HtmlBodyRenderer
    PLACEHOLDER = '<p>This message does not include an HTML body.</p>'

    def initialize(presenter, attachment_url:)
      @attachment_url = attachment_url
      @presenter = presenter
    end

    def render
      html = presenter.html_body
      return PLACEHOLDER if html.blank?

      fragment = Nokogiri::HTML::DocumentFragment.parse(html)
      rewrite_cid_images(fragment)
      rewrite_links(fragment)
      fragment.to_html
    rescue StandardError
      html.to_s
    end

    private

    attr_reader :attachment_url, :presenter

    def locator
      @locator ||= AttachmentLocator.new(presenter.record)
    end

    def rewrite_cid_images(fragment)
      fragment.css("[src^='cid:']").each do |node|
        attachment = locator.find_inline_by_cid(node['src'])
        node['src'] = attachment_url.call(attachment.id, inline: true) if attachment
      end
    end

    def rewrite_links(fragment)
      fragment.css('a[href]').each do |node|
        node['target'] = '_blank'
        rel_values = node['rel'].to_s.split | %w[noopener noreferrer]
        node['rel'] = rel_values.join(' ')
      end
    end
  end
end
