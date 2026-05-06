# frozen_string_literal: true

Rails.application.routes.draw do
  mount MailDude::Engine, at: '/mail_dude'
end
