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

      resources :stores, only: [ :index ] do
        resources :script_versions, only: [ :index, :create, :update ], controller: "store_script_versions"
      end

      namespace :admin do
        resources :stores, only: [ :index, :create ]
        resources :scripts, only: [ :index ] do
          collection do
            post :bulk_import
          end
          member do
            patch :approve
            patch :reject
          end
        end
      end

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
