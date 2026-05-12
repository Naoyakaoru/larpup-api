module Api
  module V1
    class AddressesController < ApplicationController
      skip_before_action :authenticate!, only: :index
      before_action :set_address, only: %i[update]
      before_action :require_store_owner_or_admin!, only: %i[create]
      before_action :require_address_access!, only: %i[update]

      # GET /addresses?q=name&version_id=X
      def index
        scope = Address.active
        scope = scope.where("name ILIKE ?", "%#{params[:q]}%") if params[:q].present?

        addresses = if params[:version_id].present?
          version = ScriptVersion.find_by(id: params[:version_id])
          order_by_relevance(scope, version)
        else
          scope.order(:name)
        end

        render json: addresses.map { |a| AddressSerializer.new(a).as_json }
      end

      # POST /addresses
      def create
        address = Address.new(create_params)
        if address.save
          warning = nil
          store_id = params[:store_id].presence
          if store_id
            store = Store.find_by(id: store_id)
            if store && (store.owner_id == current_user.id || current_user.is_admin?)
              StoreAddress.find_or_create_by!(store: store, address: address)
            else
              warning = "store_id not found or not accessible"
            end
          end
          json = AddressSerializer.new(address).as_json
          json[:warning] = warning if warning
          render json: json, status: :created
        else
          render json: { errors: address.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /addresses/:id
      def update
        permitted = current_user.is_admin? ? admin_update_params : store_manager_update_params
        if @address.update(permitted)
          render json: AddressSerializer.new(@address).as_json
        else
          render json: { errors: @address.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_address
        @address = Address.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Not found" }, status: :not_found
      end

      def create_params
        params.permit(:name, :address, :map_url, :region)
      end

      def admin_update_params
        params.permit(:name, :address, :map_url, :region)
      end

      def store_manager_update_params
        params.permit(:name)
      end

      def require_store_owner_or_admin!
        return if current_user.is_admin?
        unless Store.exists?(owner_id: current_user.id)
          render json: { error: "Forbidden" }, status: :forbidden
        end
      end

      def require_address_access!
        return if current_user.is_admin?
        unless @address.stores.exists?(owner_id: current_user.id)
          render json: { error: "Forbidden" }, status: :forbidden
        end
      end

      # Sort: version addresses → store addresses → rest
      def order_by_relevance(scope, version)
        return scope.order(:name) unless version

        version_ids = version.addresses.pluck(:id)
        store       = version.store
        store_ids   = store ? store.addresses.pluck(:id) - version_ids : []

        id_col = Address.arel_table[:id]
        priority = Arel::Nodes::Case.new
                     .when(id_col.in(version_ids.presence || [0])).then(0)
                     .when(id_col.in(store_ids.presence || [0])).then(1)
                     .else(2)

        scope.order(priority, :name)
      end
    end
  end
end
