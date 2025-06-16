Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "projects#index"
  resources :projects, only: [ :index ], param: :name do
    resources :versions, only: [ :index, :show, :new, :create ], param: :name
  end
  # resources :endpoints, only: [ :index, :show ]
end
