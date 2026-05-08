module Api
  module V1
    class ScriptVersionAddressesController < ApplicationController
      before_action :set_store_and_version
      before_action :require_store_access!

      def index
        render json: @version.addresses.order(:name).map { |a| AddressSerializer.new(a).as_json }
      end

      # POST /stores/:store_id/script_versions/:script_version_id/addresses
      def create
        address = Address.find(params[:address_id])
        ScriptVersionAddress.find_or_create_by!(script_version: @version, address: address)
        render json: AddressSerializer.new(address).as_json, status: :created
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Address not found" }, status: :not_found
      end

      # DELETE /stores/:store_id/script_versions/:script_version_id/addresses/:id
      def destroy
        sva = @version.script_version_addresses.find_by!(address_id: params[:id])
        sva.destroy
        head :no_content
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Not found" }, status: :not_found
      end

      private

      def set_store_and_version
        @store = Store.find(params[:store_id])
        @version = @store.script_versions.find(params[:script_version_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Not found" }, status: :not_found
      end

      def require_store_access!
        unless @store.owner_id == current_user.id || current_user.is_admin?
          render json: { error: "Forbidden" }, status: :forbidden
        end
      end
    end
  end
end
