module StoreAccessible
  extend ActiveSupport::Concern

  def require_store_access!
    unless @store.owner_id == current_user.id || current_user.is_admin?
      render json: { error: "Forbidden" }, status: :forbidden
    end
  end
end
