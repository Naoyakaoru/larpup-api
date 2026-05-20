module Api
  module V1
    class StoreScriptVersionsController < ApplicationController
      include StoreAccessible
      before_action :set_store
      before_action :require_store_access!

      def index
        versions = @store.script_versions.joins(:script).merge(Script.active).includes(:script).order(created_at: :desc)
        render json: versions.map { |v| version_json(v) }
      end

      def create
        ActiveRecord::Base.transaction do
          script = resolve_script!

          version = @store.script_versions.build(
            script: script,
            price: params[:price],
            version_name: params[:version_name].presence,
            duration_override: params[:duration_override].presence,
            npc_count: params[:npc_count].presence,
            gm_count: params[:gm_count].presence,
            has_food: params[:has_food],
            has_costume_change: params[:has_costume_change],
            available: true
          )

          version.save!

          if params[:address_ids].present?
            version.address_ids = Array(params[:address_ids]).map(&:to_i)
          end

          render json: version_json(version.reload), status: :created
        end
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      def bulk_import
        rows = params.require(:versions)
        created = 0
        errors = []

        scripts_by_title = Script.where(title: rows.map { |r| r[:title] }).index_by(&:title)
        scripts_with_base = ScriptVersion.where(store_id: nil, script_id: scripts_by_title.values.map(&:id))
                                         .pluck(:script_id).to_set
        bool = ActiveModel::Type::Boolean.new

        rows.each_with_index do |row, i|
          script = scripts_by_title[row[:title]]
          unless script
            errors << { index: i, title: row[:title], messages: [ "找不到劇本「#{row[:title]}」" ] }
            next
          end

          ActiveRecord::Base.transaction(requires_new: true) do
            unless scripts_with_base.include?(script.id)
              ScriptVersion.create!(script: script, store_id: nil, available: true)
              scripts_with_base.add(script.id)
            end

            version = @store.script_versions.build(
              script: script,
              price: row[:price].presence,
              version_name: row[:version_name].presence,
              duration_override: row[:duration_override].presence,
              npc_count: row[:npc_count].presence,
              gm_count: row[:gm_count].presence,
              has_food: row[:has_food].present? ? bool.cast(row[:has_food]) : nil,
              has_costume_change: row[:has_costume_change].present? ? bool.cast(row[:has_costume_change]) : nil,
              available: true
            )
            if version.save
              created += 1
            else
              errors << { index: i, title: row[:title], messages: version.errors.full_messages }
            end
          end
        end

        render json: { created: created, errors: errors }
      end

      def destroy
        version = @store.script_versions.find(params[:id])
        ActiveRecord::Base.transaction do
          version.update_column(:deleted_at, Time.current)
          AuditLog.create!(auditable: version, user: current_user, action: "deleted", metadata: {})
        end
        head :no_content
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Not found" }, status: :not_found
      end

      def update
        version = @store.script_versions.find(params[:id])
        if version.update(version_params)
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
            duration: params[:duration_override].presence,
            status: :pending,
            metadata: params[:cover_image_id].present? ? { "cover_image_id" => params[:cover_image_id] } : nil
          )
        end
      end

      def version_params
        params.permit(:available, :price, :version_name, :duration_override,
                      :npc_count, :gm_count, :has_food, :has_costume_change,
                      address_ids: [])
      end

      def version_json(v)
        bool = ActiveModel::Type::Boolean.new
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
          duration_override: v.duration_override&.to_f,
          npc_count: v.npc_count&.to_i,
          gm_count: v.gm_count&.to_i,
          has_food: bool.cast(v.has_food),
          has_costume_change: bool.cast(v.has_costume_change),
          address_ids: v.address_ids
        }
      end
    end
  end
end
