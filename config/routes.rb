Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  root "receipts#index"

  resources :receipts, only: [:index, :new, :create, :show]
end
