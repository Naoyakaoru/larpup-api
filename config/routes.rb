Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :auth, only: [] do
        collection do
          post :register
          post :login
          delete :logout
        end
      end

      scope "/auth/sso", controller: "sso", as: "sso_auth" do
        post :google,   action: :google,   as: :google
        post :line,     action: :line,     as: :line
        post :register, action: :register, as: :register
      end

      resources :users, only: [ :show ], param: :handle do
        collection do
          get   :me
          patch :me, action: :update
          get   "me/events", action: :events
          get   "me/stores", action: :stores
          get   :search
        end
      end

      resources :scripts, only: [ :index, :show, :create, :update ] do
        resources :versions, only: [ :index ], controller: "script_versions"
      end

      resources :addresses, only: [ :index, :create, :update ]

      resources :stores, only: [ :index ] do
        resources :script_versions, only: [ :index, :create, :update, :destroy ], controller: "store_script_versions" do
          collection do
            post :bulk_import
          end
          resources :addresses, only: [ :index, :create, :destroy ], controller: "script_version_addresses"
        end
        resources :addresses, only: [ :index, :create, :destroy ], controller: "store_addresses"
      end

      namespace :admin do
        resources :addresses, only: [ :index, :destroy ]
        resources :stores, only: [ :index, :create ]
        resources :scripts, only: [ :index, :destroy ] do
          collection do
            post :bulk_import
            get  :autofill
          end
          member do
            patch :approve
            patch :reject
            post  :cover_import
          end
        end
      end

      resources :user_consents, only: [ :index, :create ]

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
