module Api
  module V1
    module Admin
      class StoresController < ApplicationController
        before_action :require_admin!

        def index
          stores = Store.includes(:owner).order(Arel.sql("status = 'inactive'"), :name)
          render json: stores.map { |s| store_json(s) }
        end

        def create
          store = Store.new(store_params)
          if store.save
            render json: store_json(store), status: :created
          else
            render json: { errors: store.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def store_params
          params.permit(:name, :owner_id)
        end

        def store_json(store)
          {
            id: store.id,
            name: store.name,
            status: store.status,
            owner: {
              id: store.owner.id,
              handle: store.owner.handle,
              nickname: store.owner.nickname
            }
          }
        end
      end
    end
  end
end
