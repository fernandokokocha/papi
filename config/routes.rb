Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  resources :projects, only: [ :index, :new, :create ], param: :name do
    resources :candidates, only: [ :new, :create, :show, :edit, :update ], param: :name do
      match "*", to: "test_server#candidate", via: :all, constraints: CandidateTestServerConstraint.new
      resource :merge, only: [ :create ]
      resource :rejection, only: [ :create ]
    end
    resources :versions, only: [ :show ], param: :name do
      match "*", to: "test_server#version", via: :all, constraints: VersionTestServerConstraint.new
    end
    resources :endpoints, only: [ :show ]
  end

  root "projects#index"
end
