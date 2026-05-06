# frozen_string_literal: true

class TestMailer < ApplicationMailer
  def plain(to: 'to@example.com', subject: 'Plain')
    mail(to: to, subject: subject, body: 'Hello from MailDude')
  end

  def html(to: 'to@example.com', subject: 'HTML')
    mail(to: to, subject: subject, content_type: 'text/html', body: '<h1>Hello</h1>')
  end

  def with_attachment
    attachments['report.txt'] = 'Report'
    mail(to: 'to@example.com', subject: 'Attachment', body: 'Attached')
  end
end
