module Api
  module V1
    class ScriptVersionsController < ApplicationController
      skip_before_action :authenticate!

      def index
        script = Script.find(params[:script_id])
        versions = script.script_versions
                         .where.not(store_id: nil)
                         .where(available: true)
                         .includes(:store)
                         .order("stores.name")
        render json: versions.map { |v|
          {
            id: v.id,
            version_name: v.version_name,
            price: v.price,
            duration: v.effective_duration,
            store: { id: v.store.id, name: v.store.name }
          }
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Script not found" }, status: :not_found
      end
    end
  end
end
