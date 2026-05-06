module Api
  module V1
    class StoreScriptVersionsController < ApplicationController
      before_action :set_store
      before_action :require_store_access!

      def index
        versions = @store.script_versions.includes(:script).order("scripts.title")
        render json: versions.map { |v| version_json(v) }
      end

      def create
        ActiveRecord::Base.transaction do
          script = resolve_script!
          ensure_base_version!(script)

          version = @store.script_versions.build(
            script: script,
            price: params[:price],
            version_name: params[:version_name].presence,
            duration_override: params[:duration_override].presence,
            available: true
          )

          version.save!
          AuditLog.create!(auditable: version, user: current_user, action: "created",
                           metadata: { price: version.price, duration_override: version.duration_override })
          render json: version_json(version.reload), status: :created
        end
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      def update
        version = @store.script_versions.find(params[:id])
        before = version.slice(:price, :available, :duration_override, :version_name)

        if version.update(version_params)
          after = version.slice(:price, :available, :duration_override, :version_name)
          changes = after.select { |k, v| before[k] != v }.to_h { |k, v| [ k, [ before[k], v ] ] }
          AuditLog.create!(auditable: version, user: current_user, action: "updated",
                           metadata: { changes: changes }) if changes.any?
          render json: version_json(version)
        else
          render json: { errors: version.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Not found" }, status: :not_found
      end

      private

      def set_store
        @store = Store.find(params[:store_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Not found" }, status: :not_found
      end

      def require_store_access!
        unless @store.owner_id == current_user.id || current_user.is_admin?
          render json: { error: "Forbidden" }, status: :forbidden
        end
      end

      def resolve_script!
        if params[:script_id].present?
          Script.find(params[:script_id])
        else
          Script.create!(
            title: params[:title],
            difficulty: params[:difficulty],
            male_slots: params[:male_slots] || 0,
            female_slots: params[:female_slots] || 0,
            any_slots: params[:any_slots] || 0,
            genres: params[:genres] || [],
            duration: params[:duration_override],
            status: :pending
          )
        end
      end

      def ensure_base_version!(script)
        return if script.script_versions.where(store_id: nil).exists?
        script.script_versions.create!(store_id: nil, available: true)
      end

      def version_params
        params.permit(:available, :price, :version_name, :duration_override)
      end

      def version_json(v)
        {
          id: v.id,
          script: {
            id: v.script.id,
            title: v.script.title,
            difficulty: v.script.difficulty,
            total_slots: v.script.total_slots,
            status: v.script.status
          },
          version_name: v.version_name,
          price: v.price,
          available: v.available,
          duration_override: v.duration_override&.to_f
        }
      end
    end
  end
end
