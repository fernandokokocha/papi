Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "projects#index"
  resources :projects, only: [ :index, :new, :create ], param: :name do
    resources :candidates, only: [ :new, :create, :show ], param: :name do
      resource :merge, only: [ :create ]
      resource :rejection, only: [ :create ]
    end
    resources :versions, only: [ :show ], param: :name
    resources :endpoints, only: [ :show ]
  end
end
