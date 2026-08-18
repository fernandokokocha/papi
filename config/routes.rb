Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  resources :projects, only: [ :index, :new, :create ], param: :name do
    resource :openapi_import, only: [ :new, :create ], controller: "open_api_imports"
    resources :candidates, only: [ :new, :create, :show, :edit, :update ], param: :name do
      resources :comments, only: [ :create ] do
        resource :resolution, only: [ :create, :destroy ]
      end
      match "*", via: :all, to: "test_server#candidate", constraints: CandidateTestServerConstraint.new
      resource :merge, only: [ :create ]
      resource :rejection, only: [ :create ]
      resource :approval, only: [ :create, :destroy ]
    end
    resources :versions, only: [ :show ], param: :name do
      resource :openapi, only: [ :show ], controller: "open_api"
      match "*", via: :all, to: "test_server#version", constraints: VersionTestServerConstraint.new
    end
    resources :endpoints, only: [ :show ] do
      resource :history, only: [ :show ], controller: "endpoint_histories"
      resource :card, only: [ :show ], controller: "endpoint_cards"
    end
    resources :entities, only: [ :show ] do
      resource :history, only: [ :show ], controller: "entity_histories"
      resource :card, only: [ :show ], controller: "entity_cards"
    end
  end

  get "design-preview" => "design_preview#show"

  root "projects#index"
end
