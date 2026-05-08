# frozen_string_literal: true

MailDude::Engine.routes.draw do
  root 'messages#index'

  resources :messages, only: %i[index show destroy] do
    member do
      get :html
      get :text
      get 'headers', action: :message_headers
      get :raw
      get 'attachments/:attachment_id', to: 'attachments#show', as: :attachment
    end

    collection do
      delete :clear
    end
  end
end
