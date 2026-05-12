module Api
  module V1
    class StoreAddressesController < ApplicationController
      include StoreAccessible
      before_action :set_store
      before_action :require_store_access!

      def index
        render json: @store.addresses.order(:name).map { |a| AddressSerializer.new(a).as_json }
      end

      # POST /stores/:store_id/addresses — link an existing address to this store
      def create
        address = Address.find(params[:address_id])
        StoreAddress.find_or_create_by!(store: @store, address: address)
        render json: AddressSerializer.new(address).as_json, status: :created
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Address not found" }, status: :not_found
      end

      # DELETE /stores/:store_id/addresses/:id — unlink address from store
      def destroy
        sa = @store.store_addresses.find_by!(address_id: params[:id])
        sa.destroy
        head :no_content
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Not found" }, status: :not_found
      end

      private

      def set_store
        @store = Store.find(params[:store_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Not found" }, status: :not_found
      end

    end
  end
end
