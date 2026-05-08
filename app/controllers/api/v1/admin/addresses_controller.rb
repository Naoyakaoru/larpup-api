module Api
  module V1
    module Admin
      class AddressesController < ApplicationController
        before_action :require_admin!
        before_action :set_address, only: %i[destroy]

        # GET /admin/addresses — all including deleted
        def index
          addresses = Address.order(:name)
          render json: addresses.map { |a| AddressSerializer.new(a).as_json }
        end

        # DELETE /admin/addresses/:id
        def destroy
          if @address.deleted_at?
            render json: { error: "Already deleted" }, status: :unprocessable_entity
          else
            @address.soft_delete!(user: current_user)
            head :no_content
          end
        end

        private

        def set_address
          @address = Address.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Not found" }, status: :not_found
        end
      end
    end
  end
end
