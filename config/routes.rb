Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "auth/register", to: "auth#register"
      post "auth/login",    to: "auth#login"
      delete "auth/logout", to: "auth#logout"

      get   "users/me",       to: "users#me"
      patch "users/me",       to: "users#update"
      get   "users/me/events", to: "users#events"
      get   "users/:handle",   to: "users#show"

      resources :scripts, only: [ :index, :show, :create, :update ]

      resources :events, only: [ :index, :show, :create, :update, :destroy ] do
        member do
          post   :join
          delete :leave
          patch  :restore
          patch  :cancel
        end
        resources :members, only: [ :index, :update ], controller: "event_members"
      end
    end
  end
end
