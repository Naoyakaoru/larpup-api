module Api
  module V1
    class StoresController < ApplicationController
      skip_before_action :authenticate!

      def index
        stores = Store.includes(:owner).where(status: :active).order(:name)
        render json: stores.map { |s|
          {
            id: s.id,
            name: s.name,
            owner: {
              id: s.owner.id,
              handle: s.owner.handle,
              nickname: s.owner.nickname
            }
          }
        }
      end
    end
  end
end
